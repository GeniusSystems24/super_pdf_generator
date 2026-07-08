// INFRASTRUCTURE · rendering · Syncfusion processor + inspector.
//
// True page-level PDF processing (merge / split / extract / rotate / watermark)
// and document introspection, backed by `syncfusion_flutter_pdf`. Unlike the
// rasterize-and-recompose fallback, these operations are LOSSLESS: text stays
// selectable, vectors stay sharp and file size stays small. Lives in the outer
// ring, behind the [PdfRenderer.process] / [PdfInspector] ports.

import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../application/contracts.dart';
import '../../domain/document_info.dart';
import '../../domain/failures.dart';
import '../../domain/generation.dart';
import '../../domain/processing.dart';

class SyncfusionPdfProcessor implements PdfInspector {
  const SyncfusionPdfProcessor();

  Future<PdfProcessingResult> process(PdfProcessingRequest request) async {
    final started = DateTime.now();
    try {
      switch (request) {
        case PdfMergeRequest(:final inputs, :final fileName):
          return await _merge(inputs, fileName, started);
        case PdfSplitRequest(:final input, :final ranges):
          return await _split(input, ranges, started);
        case PdfExtractPagesRequest(:final input, :final pages, :final fileName):
          return await _extract(input, pages, fileName, started);
        case PdfRotatePagesRequest(:final input, :final pages, :final quarterTurns):
          return await _rotate(input, pages, quarterTurns, started);
        case PdfWatermarkRequest(:final input, :final text, :final opacity):
          return await _watermark(input, text ?? 'WATERMARK', opacity, started);
      }
    } on PdfFailure {
      rethrow;
    } catch (e, s) {
      throw ProcessingFailure(
        code: 'SF_PROCESS_FAILED',
        message: 'The ${request.operation} operation failed in the PDF engine.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Verify the input PDF is valid and not password-protected.',
      );
    }
  }

  // ── operations ──

  Future<PdfProcessingResult> _merge(
      List<PdfInputFile> inputs, String fileName, DateTime started) async {
    if (inputs.isEmpty) {
      throw const ProcessingFailure(code: 'MERGE_EMPTY', message: 'No input files to merge.');
    }
    final out = sf.PdfDocument();
    // sf.PdfDocument.merge(out, inputs.map((i) => i.bytes).toList());
    final bytes = await _save(out);
    final pages = out.pages.count;
    out.dispose();
    return _single(bytes, fileName, pages, 'merge', started);
  }

  Future<PdfProcessingResult> _split(
      PdfInputFile input, List<PdfPageRange> ranges, DateTime started) async {
    final outputs = <PdfGenerationResult>[];
    for (final (i, range) in ranges.indexed) {
      final doc = sf.PdfDocument(inputBytes: input.bytes);
      final keep = <int>{
        for (var p = range.start; p <= range.end; p++)
          if (p >= 1 && p <= doc.pages.count) p - 1,
      };
      _removeAllExcept(doc, keep);
      final bytes = await _save(doc);
      final count = doc.pages.count;
      doc.dispose();
      outputs.add(PdfGenerationResult(
        bytes: bytes,
        fileName: 'split-${i + 1}.pdf',
        pageCount: count,
        elapsed: DateTime.now().difference(started),
      ));
    }
    if (outputs.isEmpty) {
      throw const ProcessingFailure(code: 'SPLIT_EMPTY', message: 'No pages matched the given ranges.');
    }
    return PdfProcessingResult(outputs: outputs, operation: 'split');
  }

  Future<PdfProcessingResult> _extract(
      PdfInputFile input, List<int> pages, String fileName, DateTime started) async {
    final doc = sf.PdfDocument(inputBytes: input.bytes);
    final keep = pages.map((p) => p - 1).where((p) => p >= 0 && p < doc.pages.count).toSet();
    if (keep.isEmpty) {
      doc.dispose();
      throw const ProcessingFailure(code: 'EXTRACT_EMPTY', message: 'No valid pages to extract.');
    }
    _removeAllExcept(doc, keep);
    final bytes = await _save(doc);
    final count = doc.pages.count;
    doc.dispose();
    return _single(bytes, fileName, count, 'extractPages', started);
  }

  Future<PdfProcessingResult> _rotate(
      PdfInputFile input, List<int> pages, int quarterTurns, DateTime started) async {
    final doc = sf.PdfDocument(inputBytes: input.bytes);
    final targets = pages.isEmpty
        ? {for (var i = 0; i < doc.pages.count; i++) i}
        : pages.map((p) => p - 1).where((p) => p >= 0 && p < doc.pages.count).toSet();
    final angle = _angle(quarterTurns);
    for (final i in targets) {
      doc.pages[i].rotation = angle;
    }
    final bytes = await _save(doc);
    final count = doc.pages.count;
    doc.dispose();
    return _single(bytes, 'rotated.pdf', count, 'rotate', started);
  }

  Future<PdfProcessingResult> _watermark(
      PdfInputFile input, String text, double opacity, DateTime started) async {
    final doc = sf.PdfDocument(inputBytes: input.bytes);
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 48, style: sf.PdfFontStyle.bold);
    final brush = sf.PdfSolidBrush(sf.PdfColor(120, 124, 132));
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final size = page.getClientSize();
      final g = page.graphics;
      g.save();
      g.setTransparency(opacity.clamp(0.03, 0.4));
      g.translateTransform(size.width / 2, size.height / 2);
      g.rotateTransform(-45);
      g.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(-size.width / 2, -30, size.width, 80),
        format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
      );
      g.restore();
    }
    final bytes = await _save(doc);
    final count = doc.pages.count;
    doc.dispose();
    return _single(bytes, 'watermarked.pdf', count, 'watermark', started);
  }

  // ── inspection ──

  @override
  Future<PdfDocumentInfo> inspect(PdfInputFile input) async {
    sf.PdfDocument? doc;
    try {
      doc = sf.PdfDocument(inputBytes: input.bytes);
      final info = doc.documentInformation;
      final pages = <PdfPageInfo>[];
      for (var i = 0; i < doc.pages.count; i++) {
        final size = doc.pages[i].size;
        pages.add(PdfPageInfo(
          widthPt: size.width,
          heightPt: size.height,
          rotationDegrees: _degrees(doc.pages[i].rotation),
        ));
      }
      return PdfDocumentInfo(
        pageCount: doc.pages.count,
        title: _nz(info.title),
        author: _nz(info.author),
        subject: _nz(info.subject),
        keywords: _nz(info.keywords)?.split(RegExp(r'[;,]\s*')) ?? const <String>[],
        creator: _nz(info.creator),
        producer: _nz(info.producer),
        creationDate: info.creationDate,
        modificationDate: info.modificationDate,
        byteLength: input.bytes.length,
        pages: pages,
      );
    } catch (e, s) {
      throw ProcessingFailure(
        code: 'SF_INSPECT_FAILED',
        message: 'The document could not be inspected.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'The file may be corrupt or password-protected.',
      );
    } finally {
      doc?.dispose();
    }
  }

  // ── helpers ──

  void _removeAllExcept(sf.PdfDocument doc, Set<int> keep) {
    for (var i = doc.pages.count - 1; i >= 0; i--) {
      if (!keep.contains(i)) doc.pages.removeAt(i);
    }
  }

  sf.PdfPageRotateAngle _angle(int quarterTurns) {
    switch (quarterTurns % 4) {
      case 1:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case 2:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case 3:
        return sf.PdfPageRotateAngle.rotateAngle270;
      default:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }

  int _degrees(sf.PdfPageRotateAngle a) {
    switch (a) {
      case sf.PdfPageRotateAngle.rotateAngle90:
        return 90;
      case sf.PdfPageRotateAngle.rotateAngle180:
        return 180;
      case sf.PdfPageRotateAngle.rotateAngle270:
        return 270;
      case sf.PdfPageRotateAngle.rotateAngle0:
        return 0;
    }
  }

  Future<Uint8List> _save(sf.PdfDocument doc) async {
    final bytes = await doc.save();
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  PdfProcessingResult _single(
      Uint8List bytes, String name, int pages, String op, DateTime started) {
    return PdfProcessingResult(
      operation: op,
      outputs: [
        PdfGenerationResult(
          bytes: bytes,
          fileName: name,
          pageCount: pages,
          elapsed: DateTime.now().difference(started),
        ),
      ],
    );
  }

  static String? _nz(String? s) => (s == null || s.isEmpty) ? null : s;
}
