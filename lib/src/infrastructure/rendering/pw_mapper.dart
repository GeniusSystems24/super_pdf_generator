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
        header: processing.header
            ? (context) => mapper.runningHeader(processing)
            : null,
        footer: processing.pageNumbers
            ? (context) => mapper.runningFooter(context)
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
                font: bold, fontSize: 64, color: pdflib.PdfColor.fromInt(0xFF787C84)),
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
              style: pw.TextStyle(font: bold, fontSize: size, color: _ink)),
        );
      case PdfParagraph(:final text, :final align):
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Text(text,
              textAlign: _align(align),
              style: pw.TextStyle(font: base, fontSize: 11, color: _ink, lineSpacing: 2)),
        );
      case PdfText(:final text):
        return pw.Text(text, style: pw.TextStyle(font: base, fontSize: 11, color: _ink));
      case PdfRichText(:final spans):
        return pw.Text(spans.join(' '),
            style: pw.TextStyle(font: base, fontSize: 11, color: _ink));
      case PdfSpacer(:final size):
        return pw.SizedBox(height: size);
      case PdfDivider():
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Divider(height: 1, thickness: 0.6, color: pdflib.PdfColor.fromInt(0xFFE5E7EB)),
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
                              style: pw.TextStyle(font: base, fontSize: 10.5, color: _muted)),
                          pw.Text(p.value,
                              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink)),
                        ],
                      ),
                    ))
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
                          style: pw.TextStyle(font: base, fontSize: 11, color: _muted)),
                    ),
                    pw.Expanded(
                      child: pw.Text(it,
                          style: pw.TextStyle(font: base, fontSize: 11, color: _ink)),
                    ),
                  ]),
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
      case PdfSignatureBlock(:final name, :final role):
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 24),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(width: 180, height: 0.8, color: _ink),
            pw.SizedBox(height: 4),
            pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
            pw.Text(role, style: pw.TextStyle(font: base, fontSize: 9, color: _muted)),
          ]),
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
        return pw.Text(format, style: pw.TextStyle(font: base, fontSize: 9, color: _muted));
      case PdfImage(:final label):
        return _placeholder(label, height: 90);
      case PdfSvg():
        return _placeholder('SVG', height: 90);
      case PdfChartPlaceholder(:final label):
        return _placeholder(label, height: 120);
      case PdfQrCode(:final value):
        return _placeholder('QR · $value', height: 90, square: true);
      case PdfBarcode(:final value):
        return _placeholder('barcode · $value', height: 56);
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
          color: header ? _ink : (alt ? pdflib.PdfColor.fromInt(0xFFF5F6F8) : null),
          child: pw.Text(
            s,
            style: pw.TextStyle(
              font: header ? bold : base,
              fontSize: header ? 9 : 9.5,
              color: header ? pdflib.PdfColor.fromInt(0xFFFFFFFF) : _ink,
            ),
          ),
        );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Table(
        border: pw.TableBorder.all(color: pdflib.PdfColor.fromInt(0xFFE8E9EC), width: 0.5),
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
              style: pw.TextStyle(font: bold, fontSize: 9, color: pdflib.PdfColor.fromInt(0xFFFFFFFF))),
        ),
      ]),
    );
  }

  pw.Widget _placeholder(String label, {required double height, bool square = false}) {
    final box = pw.Container(
      height: height,
      width: square ? height : null,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: pdflib.PdfColor.fromInt(0xFFF4F5F7),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: pdflib.PdfColor.fromInt(0xFFD2D5DB), width: 0.6),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(font: base, fontSize: 9, color: pdflib.PdfColor.fromInt(0xFF9AA0AA))),
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: square ? pw.Align(alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: box) : box,
    );
  }

  pw.Widget runningHeader(PdfPostProcessing proc) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 1.2))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(document.metadata.title,
              style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink)),
          pw.Text(document.metadata.author,
              style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted)),
        ]),
      );

  pw.Widget runningFooter(pw.Context context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Folio', style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted)),
          pw.Text('Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: base, fontSize: 8.5, color: _muted)),
        ]),
      );

  pdflib.PdfColor _tone(String tone) => switch (tone) {
        'green' => pdflib.PdfColor.fromInt(0xFF1DB88A),
        'orange' => pdflib.PdfColor.fromInt(0xFFF97316),
        'red' => pdflib.PdfColor.fromInt(0xFFEF4444),
        _ => _accent,
      };

  pdflib.PdfColor _tint(pdflib.PdfColor c) =>
      pdflib.PdfColor(c.red, c.green, c.blue, 0.08);
}
