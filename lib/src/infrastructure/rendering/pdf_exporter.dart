// INFRASTRUCTURE · rendering · exporter.
//
// Converts an existing PDF into another representation:
//   • plainText — text extracted with Syncfusion's PdfTextExtractor
//   • image     — per-page rasters via the `printing` engine, encoded PNG/JPEG
//   • html      — a self-contained page (embedded page images + optional text)
//   • pdfA      — re-emitted under a PDF/A archival conformance profile
//
// Outer-ring adapter behind the [PdfExporter] port; the pure layers never see
// the engine, `printing`, or the image codecs.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../application/contracts.dart';
import '../../domain/export.dart';
import '../../domain/failures.dart';

/// Exports PDFs to HTML / image / text / PDF-A.
class SyncfusionPdfExporter implements PdfExporter {
  const SyncfusionPdfExporter();

  @override
  Future<PdfExportResult> export(PdfExportRequest request) async {
    try {
      return switch (request) {
        PdfTextExportRequest() => await _text(request),
        PdfImageExportRequest() => await _image(request),
        PdfHtmlExportRequest() => await _html(request),
        PdfAExportRequest() => await _pdfA(request),
      };
    } on PdfFailure {
      rethrow;
    } catch (e, s) {
      throw ExportFailure(
        code: 'SF_EXPORT_FAILED',
        message: 'The document could not be exported to ${request.format.name}.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Verify the input PDF is valid and not password-protected.',
      );
    }
  }

  // ── text ──

  Future<PdfExportResult> _text(PdfTextExportRequest request) async {
    final doc = sf.PdfDocument(inputBytes: request.input.bytes);
    try {
      final extractor = sf.PdfTextExtractor(doc);
      final artifacts = <PdfExportArtifact>[];
      if (request.perPage) {
        for (var i = 0; i < doc.pages.count; i++) {
          final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
          artifacts.add(PdfExportArtifact(
            name: 'page-${i + 1}.txt',
            bytes: _utf8(text),
            mimeType: 'text/plain; charset=utf-8',
          ),);
        }
      } else {
        final text = extractor.extractText();
        artifacts.add(PdfExportArtifact(
          name: request.fileName,
          bytes: _utf8(text),
          mimeType: 'text/plain; charset=utf-8',
        ),);
      }
      return PdfExportResult(
        artifacts: artifacts,
        format: PdfExportFormat.plainText,
      );
    } finally {
      doc.dispose();
    }
  }

  // ── image ──

  Future<PdfExportResult> _image(PdfImageExportRequest request) async {
    final pages = request.pages.isEmpty
        ? null
        : request.pages.map((p) => p - 1).where((p) => p >= 0).toList();
    final isPng = request.rasterFormat == PdfRasterFormat.png;
    final artifacts = <PdfExportArtifact>[];
    var index = 0;
    await for (final raster in Printing.raster(
      request.input.bytes,
      pages: pages,
      dpi: request.dpi,
    )) {
      final page = img.Image.fromBytes(
        width: raster.width,
        height: raster.height,
        bytes: raster.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final bytes = isPng
          ? img.encodePng(page)
          : img.encodeJpg(page, quality: request.quality.clamp(1, 100));
      final n = (pages == null ? index : pages[index]) + 1;
      artifacts.add(PdfExportArtifact(
        name: 'page-$n.${isPng ? 'png' : 'jpg'}',
        bytes: bytes,
        mimeType: isPng ? 'image/png' : 'image/jpeg',
      ),);
      index++;
    }
    if (artifacts.isEmpty) {
      throw const ExportFailure(
        code: 'EXPORT_NO_PAGES',
        message: 'No pages were rasterized for image export.',
      );
    }
    return PdfExportResult(artifacts: artifacts, format: PdfExportFormat.image);
  }

  // ── html ──

  Future<PdfExportResult> _html(PdfHtmlExportRequest request) async {
    final buffer = StringBuffer();
    final title = _escape(request.title ?? request.input.name);
    buffer.writeln('<!doctype html>');
    buffer.writeln('<html><head><meta charset="utf-8">');
    buffer.writeln('<meta name="viewport" content="width=device-width, initial-scale=1">');
    buffer.writeln('<title>$title</title>');
    buffer.writeln('<style>body{margin:0;background:#525659;font-family:system-ui,sans-serif}'
        '.page{display:block;margin:16px auto;max-width:900px;width:100%;'
        'box-shadow:0 2px 12px rgba(0,0,0,.4)}'
        '.txt{max-width:900px;margin:16px auto;padding:16px;background:#fff;'
        'white-space:pre-wrap;line-height:1.5}</style>');
    buffer.writeln('</head><body>');

    var pageIndex = 0;
    await for (final raster in Printing.raster(
      request.input.bytes,
      dpi: request.dpi,
    )) {
      final png = img.encodePng(img.Image.fromBytes(
        width: raster.width,
        height: raster.height,
        bytes: raster.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      ),);
      final b64 = base64Encode(png);
      buffer.writeln('<img class="page" alt="Page ${pageIndex + 1}" '
          'src="data:image/png;base64,$b64">');
      pageIndex++;
    }

    if (request.includeText) {
      final doc = sf.PdfDocument(inputBytes: request.input.bytes);
      try {
        final text = sf.PdfTextExtractor(doc).extractText();
        if (text.trim().isNotEmpty) {
          buffer.writeln('<div class="txt">${_escape(text)}</div>');
        }
      } finally {
        doc.dispose();
      }
    }

    buffer.writeln('</body></html>');
    return PdfExportResult(
      format: PdfExportFormat.html,
      artifacts: [
        PdfExportArtifact(
          name: request.fileName,
          bytes: _utf8(buffer.toString()),
          mimeType: 'text/html; charset=utf-8',
        ),
      ],
    );
  }

  // ── pdf/a ──

  Future<PdfExportResult> _pdfA(PdfAExportRequest request) async {
    final source = sf.PdfDocument(inputBytes: request.input.bytes);
    final out = sf.PdfDocument(conformanceLevel: _conformance(request.conformance));
    try {
      for (var i = 0; i < source.pages.count; i++) {
        final template = source.pages[i].createTemplate();
        final section = out.sections!.add();
        section.pageSettings.size = template.size;
        section.pageSettings.margins.all = 0;
        section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
      }
      final bytes = await _save(out);
      return PdfExportResult(
        format: PdfExportFormat.pdfA,
        artifacts: [
          PdfExportArtifact(
            name: request.fileName,
            bytes: bytes,
            mimeType: 'application/pdf',
          ),
        ],
      );
    } finally {
      source.dispose();
      out.dispose();
    }
  }

  sf.PdfConformanceLevel _conformance(PdfAConformance c) => switch (c) {
        PdfAConformance.a1b => sf.PdfConformanceLevel.a1b,
        PdfAConformance.a2b => sf.PdfConformanceLevel.a2b,
        PdfAConformance.a3b => sf.PdfConformanceLevel.a3b,
      };

  Future<Uint8List> _save(sf.PdfDocument doc) async {
    final bytes = await doc.save();
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
