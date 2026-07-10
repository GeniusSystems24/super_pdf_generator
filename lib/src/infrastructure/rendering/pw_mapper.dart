// INFRASTRUCTURE · rendering · pw mapper. PURE DART (pdf package + domain only).
//
// Deliberately free of Flutter and the `printing` plugin so it can execute
// inside a Dart isolate (the analogue of the Web design's Web Worker). It maps
// an immutable, serializable [PdfDocumentDefinition] to real PDF bytes using
// the `pdf` package's widget layer.
//
// Font policy: uses the built-in Helvetica/Courier standard fonts, which need
// no async loading and work inside an isolate. Custom/Arabic TTF registration
// is layered on by the main-thread renderer (see widget_pdf_renderer.dart).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdflib;
import 'package:pdf/widgets.dart' as pw;

import '../../domain/components.dart';
import '../../domain/document.dart';
import '../../domain/generation.dart';
import '../../domain/value_objects.dart';

/// Render a document (as JSON) to bytes + an estimated page count.
/// JSON in / record out keeps every argument sendable across an isolate.
Future<(Uint8List, int)> renderDocumentJson(
  Map<String, Object?> documentJson,
  Map<String, Object?> processingJson, {
  Uint8List? baseFontBytes,
  Uint8List? boldFontBytes,
  Uint8List? arabicFontBytes,
}) {
  final document = PdfDocumentDefinition.fromJson(documentJson);
  final processing = PdfPostProcessing.fromJson(processingJson);
  return renderDocument(
    document,
    processing,
    baseFontBytes: baseFontBytes,
    boldFontBytes: boldFontBytes,
    arabicFontBytes: arabicFontBytes,
  );
}

/// Render a document to bytes + estimated page count.
Future<(Uint8List, int)> renderDocument(
  PdfDocumentDefinition document,
  PdfPostProcessing processing, {
  Uint8List? baseFontBytes,
  Uint8List? boldFontBytes,
  Uint8List? arabicFontBytes,
}) async {
  final base = baseFontBytes != null
      ? pw.Font.ttf(ByteData.view(baseFontBytes.buffer))
      : pw.Font.helvetica();
  final bold = boldFontBytes != null
      ? pw.Font.ttf(ByteData.view(boldFontBytes.buffer))
      : pw.Font.helveticaBold();
  final arabic =
      arabicFontBytes != null ? pw.Font.ttf(ByteData.view(arabicFontBytes.buffer)) : base;

  final mapper = _PwMapper(
    document: document,
    base: base,
    bold: bold,
    arabic: arabic,
  );

  final doc = pw.Document(
    title: document.metadata.title,
    author: document.metadata.author,
    theme: pw.ThemeData.withFont(base: base, bold: bold, fontFallback: [arabic]),
  );

  final rtl = document.direction == PdfDirection.rtl;
  final pages =
      document.pages.isEmpty ? const [PdfPageDefinition()] : document.pages;

  for (final page in pages) {
    final oriented = page.size.oriented(page.orientation);
    final format = pdflib.PdfPageFormat(
      oriented.widthPt,
      oriented.heightPt,
      marginLeft: page.margins.left,
      marginTop: page.margins.top,
      marginRight: page.margins.right,
      marginBottom: page.margins.bottom,
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          theme: pw.ThemeData.withFont(base: base, bold: bold, fontFallback: [arabic]),
          buildBackground: processing.hasWatermark
              ? (context) => _watermark(processing, bold)
              : null,
        ),
        header: (processing.header || processing.headerText != null)
            ? (context) => mapper.runningHeader(context, processing)
            : null,
        footer: (processing.pageNumbers || processing.footerText != null)
            ? (context) => mapper.runningFooter(context, processing)
            : null,
        build: (context) =>
            page.content.map(mapper.map).toList(growable: false),
      ),
    );
  }

  final bytes = await doc.save();
  return (bytes, _estimatePageCount(document));
}

int _estimatePageCount(PdfDocumentDefinition d) {
  var n = d.pages.isEmpty ? 1 : d.pages.length;
  for (final p in d.pages) {
    n += p.content.whereType<PdfPageBreak>().length;
  }
  return n < 1 ? 1 : n;
}

pw.Widget _watermark(PdfPostProcessing proc, pw.Font bold) {
  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Center(
      child: pw.Transform.rotate(
        angle: math.pi / 4,
        child: pw.Opacity(
          opacity: proc.watermarkOpacity.clamp(0.03, 0.4),
          child: pw.Text(
            proc.watermarkText ?? '',
            style: pw.TextStyle(
                font: bold, fontSize: 64, color: const pdflib.PdfColor.fromInt(0xFF787C84),),
          ),
        ),
      ),
    ),
  );
}

/// Maps the domain component tree onto `pw` widgets.
class _PwMapper {
  _PwMapper({
    required this.document,
    required this.base,
    required this.bold,
    required this.arabic,
  });

  final PdfDocumentDefinition document;
  final pw.Font base;
  final pw.Font bold;
  final pw.Font arabic;

  bool get rtl => document.direction == PdfDirection.rtl;

  pdflib.PdfColor _c(PdfColor c) => pdflib.PdfColor.fromInt(c.argb);
  pdflib.PdfColor get _ink => _c(document.theme.palette.ink);
  pdflib.PdfColor get _muted => _c(document.theme.palette.muted);
  pdflib.PdfColor get _accent => _c(document.theme.palette.accent);

  pw.TextAlign _align(PdfAlign a) => switch (a) {
        PdfAlign.center => pw.TextAlign.center,
        PdfAlign.justify => pw.TextAlign.justify,
        PdfAlign.end => rtl ? pw.TextAlign.left : pw.TextAlign.right,
        PdfAlign.start => rtl ? pw.TextAlign.right : pw.TextAlign.left,
      };

  pw.Widget map(PdfComponent c) {
    switch (c) {
      case PdfHeading(:final text, :final level):
        final size = level == 1 ? 21.0 : (level == 3 ? 13.0 : 16.0);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
          child: pw.Text(text,
              style: pw.TextStyle(font: bold, fontSize: size, color: _ink),),
        );
      case PdfParagraph(:final text, :final align):
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(text,
              textAlign: _align(align),
              style: pw.TextStyle(font: base, fontSize: 11, color: _ink, lineSpacing: 2),),
        );
      case PdfText(:final text):
        return pw.Text(text, style: pw.TextStyle(font: base, fontSize: 11, color: _ink));
      case PdfRichText(:final spans):
        return pw.Text(spans.join(' '),
            style: pw.TextStyle(font: base, fontSize: 11, color: _ink),);
      case PdfSpacer(:final size):
        return pw.SizedBox(height: size);
      case PdfDivider():
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Divider(height: 1, thickness: 0.6, color: const pdflib.PdfColor.fromInt(0xFFE5E7EB)),
        );
      case PdfPageBreak():
        return pw.NewPage();
      case PdfKeyValueSection(:final pairs):
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Column(
            children: pairs
                .map((p) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(p.key,
                              style: pw.TextStyle(font: base, fontSize: 10.5, color: _muted),),
                          pw.Text(p.value,
                              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink),),
                        ],
                      ),
                    ),)
                .toList(),
          ),
        );
      case PdfList(:final items, :final ordered):
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (i, it) in items.indexed)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.SizedBox(
                      width: 18,
                      child: pw.Text(ordered ? '${i + 1}.' : '•',
                          style: pw.TextStyle(font: base, fontSize: 11, color: _muted),),
                    ),
                    pw.Expanded(
                      child: pw.Text(it,
                          style: pw.TextStyle(font: base, fontSize: 11, color: _ink),),
                    ),
                  ],),
                ),
            ],
          ),
        );
      case PdfTable(:final columns, :final rows, :final zebra):
        return _table(columns, rows, zebra);
      case PdfStatusBadge(:final label, :final tone):
        return _badge(label, tone);
      case PdfInfoBox(:final text, :final tone):
        final col = _tone(tone);
        return pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _tint(col),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border(left: pw.BorderSide(color: col, width: 3)),
          ),
          child: pw.Text(text, style: pw.TextStyle(font: base, fontSize: 10.5, color: _ink)),
        );
      case PdfSignatureBlock(:final name, :final role, :final dateLabel):
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 24),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 180, height: 0.8, color: _ink),
            pw.SizedBox(height: 4),
            pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
            pw.Text(role, style: pw.TextStyle(font: base, fontSize: 9, color: _muted)),
            if (dateLabel != null && dateLabel.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('$dateLabel  ',
                    style: pw.TextStyle(font: base, fontSize: 9, color: _muted),),
                pw.Container(width: 90, height: 0.6, color: _muted),
              ],),
            ],
          ],),
        );
      case PdfHeader(:final title):
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 18, color: _ink)),
        );
      case PdfFooter(:final text):
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(text, style: pw.TextStyle(font: base, fontSize: 9, color: _muted)),
        );
      case PdfPageNumber(:final format):
        return pw.Text(
            _applyDocTokens(format,
                title: document.metadata.title, author: document.metadata.author,),
            style: pw.TextStyle(font: base, fontSize: 9, color: _muted),);
      case PdfImage(:final label):
        return _placeholder(label, height: 90);
      case PdfSvg():
        return _placeholder('SVG', height: 90);
      case final PdfChart chart:
        return _chart(chart);
      case PdfQrCode(:final value):
        return _qr(value);
      case final PdfBarcode bc:
        return _barcode(bc.value, bc.symbology);
      case final PdfWatermark wm:
        return _watermarkInline(wm);
      case final PdfStamp st:
        return _stamp(st);
      case final PdfTextFormField f:
        return _textField(f);
      case final PdfCheckboxField f:
        return _checkboxField(f);
      case final PdfSignatureFormField f:
        return _signatureField(f);
      case PdfContainerBase():
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: c.children.map(map).toList(),
        );
    }
  }

  pw.Widget _table(List<String> columns, List<List<String>> rows, bool zebra) {
    final order = List<int>.generate(columns.length, (i) => i);
    if (rtl) order.setAll(0, order.reversed.toList());
    pw.Widget cell(String s, {required bool header, required bool alt}) => pw.Container(
          alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: header ? _ink : (alt ? const pdflib.PdfColor.fromInt(0xFFF5F6F8) : null),
          child: pw.Text(
            s,
            style: pw.TextStyle(
              font: header ? bold : base,
              fontSize: header ? 9 : 9.5,
              color: header ? const pdflib.PdfColor.fromInt(0xFFFFFFFF) : _ink,
            ),
          ),
        );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Table(
        border: pw.TableBorder.all(color: const pdflib.PdfColor.fromInt(0xFFE8E9EC), width: 0.5),
        children: [
          pw.TableRow(children: order.map((i) => cell(columns[i], header: true, alt: false)).toList()),
          for (final (r, row) in rows.indexed)
            pw.TableRow(
              children: order
                  .map((i) => cell(i < row.length ? row[i] : '', header: false, alt: zebra && r.isOdd))
                  .toList(),
            ),
        ],
      ),
    );
  }

  pw.Widget _badge(String label, String tone) {
    final col = _tone(tone);
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: pw.BoxDecoration(color: col, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(label,
              style: pw.TextStyle(font: bold, fontSize: 9, color: const pdflib.PdfColor.fromInt(0xFFFFFFFF)),),
        ),
      ],),
    );
  }

  pw.Widget _placeholder(String label, {required double height, bool square = false}) {
    final box = pw.Container(
      height: height,
      width: square ? height : null,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: const pdflib.PdfColor.fromInt(0xFFF4F5F7),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: const pdflib.PdfColor.fromInt(0xFFD2D5DB), width: 0.6),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(font: base, fontSize: 9, color: const pdflib.PdfColor.fromInt(0xFF9AA0AA)),),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: square ? pw.Align(alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: box) : box,
    );
  }

  // ---- charts -------------------------------------------------------------

  static const List<int> _chartPalette = <int>[
    0xFF2A6FDB, 0xFF1DB88A, 0xFFF97316, 0xFF8B5CF6, 0xFFEF4444, 0xFF0EA5E9,
  ];

  pdflib.PdfColor _seriesColor(PdfChartSeries s, int i) => s.color != null
      ? pdflib.PdfColor.fromInt(s.color!)
      : pdflib.PdfColor.fromInt(_chartPalette[i % _chartPalette.length]);

  double _maxValue(PdfChart chart) {
    var m = 0.0;
    for (final s in chart.series) {
      for (final v in s.values) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  pw.Widget _chart(PdfChart chart) {
    final plot = switch (chart.chartType) {
      PdfChartType.bar => _barChart(chart),
      PdfChartType.line => _lineAreaChart(chart, area: false),
      PdfChartType.area => _lineAreaChart(chart, area: true),
      PdfChartType.pie => _pieChart(chart),
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (chart.title != null && chart.title!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(chart.title!,
                style: pw.TextStyle(font: bold, fontSize: 12, color: _ink),),
          ),
        plot,
        if (chart.chartType != PdfChartType.pie && chart.series.length > 1) ...[
          pw.SizedBox(height: 6),
          _chartLegend(chart),
        ],
      ],),
    );
  }

  pw.Widget _chartLegend(PdfChart chart) => pw.Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var i = 0; i < chart.series.length; i++)
            pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Container(width: 9, height: 9, color: _seriesColor(chart.series[i], i)),
              pw.SizedBox(width: 5),
              pw.Text(chart.series[i].name,
                  style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted),),
            ],),
        ],
      );

  pw.Widget _barChart(PdfChart chart) {
    final maxV = _maxValue(chart);
    final groups = chart.labels.isNotEmpty
        ? chart.labels.length
        : (chart.series.isEmpty ? 0 : chart.series.first.values.length);
    final plotH = chart.height - 26;
    double barH(PdfChartSeries s, int g) => (g >= s.values.length || maxV <= 0)
        ? 0
        : (s.values[g] / maxV * plotH).clamp(0, plotH);
    return pw.SizedBox(
      height: chart.height,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          for (var g = 0; g < groups; g++)
            pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      for (var si = 0; si < chart.series.length; si++)
                        pw.Container(
                          width: chart.series.length <= 1 ? 22 : 12,
                          height: barH(chart.series[si], g),
                          margin: const pw.EdgeInsets.symmetric(horizontal: 1.5),
                          color: _seriesColor(chart.series[si], si),
                        ),
                    ],),
                pw.SizedBox(height: 4),
                pw.SizedBox(
                  width: 46,
                  child: pw.Text(
                      g < chart.labels.length ? chart.labels[g] : '${g + 1}',
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                      style: pw.TextStyle(font: base, fontSize: 7.5, color: _muted),),
                ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _lineAreaChart(PdfChart chart, {required bool area}) {
    const w = 460.0;
    final h = chart.height;
    return pw.Align(
      alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.SizedBox(
        width: w,
        height: h,
        child: pw.CustomPaint(
          size: pdflib.PdfPoint(w, h),
          painter: (canvas, size) => _paintLineArea(canvas, w, h, chart, area),
        ),
      ),
    );
  }

  void _paintLineArea(
      pdflib.PdfGraphics canvas, double w, double h, PdfChart chart, bool area,) {
    final maxV = _maxValue(chart);
    if (maxV <= 0) return;
    const padL = 4.0, padR = 4.0, padB = 16.0, padT = 6.0;
    final plotW = w - padL - padR;
    final plotH = h - padB - padT;
    canvas
      ..setLineWidth(0.6)
      ..setColor(const pdflib.PdfColor.fromInt(0xFFD2D5DB))
      ..drawLine(padL, padB, w - padR, padB)
      ..strokePath();
    for (var si = 0; si < chart.series.length; si++) {
      final s = chart.series[si];
      final n = s.values.length;
      if (n == 0) continue;
      final col = _seriesColor(s, si);
      double xAt(int i) => padL + (n == 1 ? plotW / 2 : plotW * i / (n - 1));
      double yAt(double v) => padB + (v / maxV) * plotH;
      if (area) {
        canvas
          ..setColor(pdflib.PdfColor(col.red, col.green, col.blue, 0.18))
          ..moveTo(xAt(0), padB);
        for (var i = 0; i < n; i++) {
          canvas.lineTo(xAt(i), yAt(s.values[i]));
        }
        canvas
          ..lineTo(xAt(n - 1), padB)
          ..closePath()
          ..fillPath();
      }
      canvas
        ..setColor(col)
        ..setLineWidth(1.4)
        ..moveTo(xAt(0), yAt(s.values[0]));
      for (var i = 1; i < n; i++) {
        canvas.lineTo(xAt(i), yAt(s.values[i]));
      }
      canvas.strokePath();
    }
  }

  pw.Widget _pieChart(PdfChart chart) {
    final h = chart.height;
    final d = h + 20;
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(
        width: d,
        height: h,
        child: pw.CustomPaint(
          size: pdflib.PdfPoint(d, h),
          painter: (canvas, size) => _paintPie(canvas, d, h, chart),
        ),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(child: _pieLegend(chart)),
    ],);
  }

  void _paintPie(pdflib.PdfGraphics canvas, double w, double h, PdfChart chart) {
    if (chart.series.isEmpty) return;
    final values = chart.series.first.values;
    final total = values.fold<double>(0, (a, b) => a + (b <= 0 ? 0 : b));
    if (total <= 0) return;
    final cx = w / 2, cy = h / 2;
    final r = (math.min(w, h) / 2) - 6;
    var start = math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final sweep = (v / total) * math.pi * 2;
      canvas
        ..setColor(pdflib.PdfColor.fromInt(_chartPalette[i % _chartPalette.length]))
        ..moveTo(cx, cy);
      const steps = 48;
      for (var k = 0; k <= steps; k++) {
        final a = start - sweep * (k / steps);
        canvas.lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
      }
      canvas
        ..closePath()
        ..fillPath();
      start -= sweep;
    }
  }

  pw.Widget _pieLegend(PdfChart chart) {
    final values =
        chart.series.isEmpty ? const <double>[] : chart.series.first.values;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        for (var i = 0; i < values.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.Container(
                  width: 9,
                  height: 9,
                  color: pdflib.PdfColor.fromInt(
                      _chartPalette[i % _chartPalette.length],),),
              pw.SizedBox(width: 6),
              pw.Text(
                  '${i < chart.labels.length ? chart.labels[i] : 'Item ${i + 1}'}  ·  ${_fmtNum(values[i])}',
                  style: pw.TextStyle(font: base, fontSize: 9, color: _ink),),
            ],),
          ),
      ],
    );
  }

  // ---- barcodes -----------------------------------------------------------

  pw.Barcode _symbology(String s) => switch (s.toLowerCase()) {
        'qr' || 'qrcode' => pw.Barcode.qrCode(),
        'code39' => pw.Barcode.code39(),
        'ean13' => pw.Barcode.ean13(),
        'ean8' => pw.Barcode.ean8(),
        'upca' => pw.Barcode.upcA(),
        'datamatrix' => pw.Barcode.dataMatrix(),
        'pdf417' => pw.Barcode.pdf417(),
        _ => pw.Barcode.code128(),
      };

  pw.Widget _barcode(String value, String symbology) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Align(
          alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.BarcodeWidget(
            barcode: _symbology(symbology),
            data: value,
            width: 180,
            height: 56,
            drawText: true,
            color: _ink,
          ),
        ),
      );

  pw.Widget _qr(String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Align(
          alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: value,
            width: 96,
            height: 96,
            drawText: false,
            color: _ink,
          ),
        ),
      );

  // ---- overlays -----------------------------------------------------------

  pw.Widget _watermarkInline(PdfWatermark w) => pw.Container(
        height: (w.fontSize * 2).clamp(60, 260),
        alignment: pw.Alignment.center,
        child: pw.Opacity(
          opacity: w.opacity.clamp(0.03, 0.5),
          child: pw.Transform.rotate(
            angle: w.angle,
            child: pw.Text(w.text,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: w.fontSize,
                    color: const pdflib.PdfColor.fromInt(0xFF787C84),),),
          ),
        ),
      );

  pw.Widget _stamp(PdfStamp s) {
    final col = _tone(s.tone);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Align(
        alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Transform.rotate(
          angle: s.angle,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: col, width: 2.4),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Text(s.text.toUpperCase(),
                  style: pw.TextStyle(
                      font: bold, fontSize: 17, color: col, letterSpacing: 1.5,),),
              if (s.date != null && s.date!.isNotEmpty)
                pw.Text(s.date!,
                    style: pw.TextStyle(font: base, fontSize: 8, color: col),),
            ],),
          ),
        ),
      ),
    );
  }

  // ---- form fields (AcroForm) --------------------------------------------

  pw.Widget _labeledField(String label, pw.Widget field) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (label.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(label,
                  style: pw.TextStyle(font: base, fontSize: 9, color: _muted),),
            ),
          field,
        ],),
      );

  pw.Widget _textField(PdfTextFormField f) {
    final h = f.multiline ? (f.height < 44 ? 60.0 : f.height) : f.height;
    if (f.value.isNotEmpty) {
      return _labeledField(
        f.label,
        pw.Container(
          width: f.width,
          height: h,
          alignment: rtl ? pw.Alignment.topRight : pw.Alignment.topLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: const pdflib.PdfColor.fromInt(0xFFC9CDD4), width: 0.8,),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(f.value,
              style: pw.TextStyle(font: base, fontSize: 10.5, color: _ink),),
        ),
      );
    }
    return _labeledField(
      f.label,
      pw.TextField(name: f.name, width: f.width, height: h),
    );
  }

  pw.Widget _checkboxField(PdfCheckboxField f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(children: [
          pw.Checkbox(name: f.name, value: f.checked, width: 12, height: 12),
          pw.SizedBox(width: 7),
          pw.Text(f.label,
              style: pw.TextStyle(font: base, fontSize: 10.5, color: _ink),),
        ],),
      );

  pw.Widget _signatureField(PdfSignatureFormField f) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: f.width,
            height: f.height,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: const pdflib.PdfColor.fromInt(0xFFC9CDD4), width: 0.8,),
              borderRadius: pw.BorderRadius.circular(3),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(f.label,
              style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted),),
        ],),
      );

  // ---- running header / footer + tokens ----------------------------------

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmtDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String _applyDocTokens(String t,
      {required String title, required String author, DateTime? now,}) {
    final d = now ?? DateTime.now();
    return t
        .replaceAll('{title}', title)
        .replaceAll('{author}', author)
        .replaceAll('{date}', _fmtDate(d))
        .replaceAll('{time}', _fmtTime(d))
        .replaceAll('{datetime}', '${_fmtDate(d)} ${_fmtTime(d)}');
  }

  static String _applyPageTokens(String t,
          {required int page, required int total,}) =>
      t.replaceAll('{page}', '$page').replaceAll('{total}', '$total');

  pw.Widget runningHeader(pw.Context context, PdfPostProcessing proc) {
    final custom = proc.headerText;
    if (custom != null && custom.trim().isNotEmpty) {
      final text = _applyPageTokens(
        _applyDocTokens(custom,
            title: document.metadata.title, author: document.metadata.author,),
        page: context.pageNumber,
        total: context.pagesCount,
      );
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1.2)),),
        child: pw.Text(text,
            style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink),),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1.2)),),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(document.metadata.title,
            style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink),),
        pw.Text(document.metadata.author,
            style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted),),
      ],),
    );
  }

  pw.Widget runningFooter(pw.Context context, PdfPostProcessing proc) {
    final custom = proc.footerText;
    if (custom != null && custom.trim().isNotEmpty) {
      final text = _applyPageTokens(
        _applyDocTokens(custom,
            title: document.metadata.title, author: document.metadata.author,),
        page: context.pageNumber,
        total: context.pagesCount,
      );
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(text,
            style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted),),
      );
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Folio', style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted)),
        pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted),),
      ],),
    );
  }

  pdflib.PdfColor _tone(String tone) => switch (tone) {
        'green' => const pdflib.PdfColor.fromInt(0xFF1DB88A),
        'orange' => const pdflib.PdfColor.fromInt(0xFFF97316),
        'red' => const pdflib.PdfColor.fromInt(0xFFEF4444),
        _ => _accent,
      };

  pdflib.PdfColor _tint(pdflib.PdfColor c) =>
      pdflib.PdfColor(c.red, c.green, c.blue, 0.08);
}
