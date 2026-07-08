// INFRASTRUCTURE · rendering · widget renderer (main isolate).
//
// Implements the [PdfRenderer] port. `render` delegates to the pure pw mapper;
// `process` (merge/split/extract/rotate/watermark) rasterizes arbitrary input
// PDFs with the `printing` plugin and re-composes them — so it works on any
// input, not only Folio-generated documents. Rasterization needs the platform
// PDF backend, so `process` always runs on the main isolate.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdflib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../application/contracts.dart';
import '../../domain/failures.dart';
import '../../domain/generation.dart';
import '../../domain/processing.dart';
import 'pw_mapper.dart';

class WidgetPdfRenderer implements PdfRenderer {
  WidgetPdfRenderer({
    this.baseFontBytes,
    this.boldFontBytes,
    this.arabicFontBytes,
    this.rasterDpi = 150,
  });

  final Uint8List? baseFontBytes;
  final Uint8List? boldFontBytes;
  final Uint8List? arabicFontBytes;
  final double rasterDpi;

  @override
  Future<PdfRenderResult> render(PdfRenderRequest request,
      [PdfRenderContext? context]) async {
    context?.onProgress?.call(const PdfGenerationProgress(fraction: 0.15, note: 'preparing'));
    final (bytes, pages) = await renderDocument(
      request.document,
      request.processing,
      baseFontBytes: baseFontBytes,
      boldFontBytes: boldFontBytes,
      arabicFontBytes: arabicFontBytes,
    );
    context?.onProgress?.call(const PdfGenerationProgress(fraction: 1, note: 'done'));
    return PdfRenderResult(bytes: bytes, pageCount: pages);
  }

  @override
  Future<PdfProcessingResult> process(PdfProcessingRequest request) async {
    final started = DateTime.now();
    switch (request) {
      case PdfMergeRequest(:final inputs, :final fileName):
        final imgs = <_Raster>[];
        for (final input in inputs) {
          imgs.addAll(await _raster(input.bytes));
        }
        final bytes = await _compose(imgs);
        return _single(bytes, fileName, imgs.length, 'merge', started);

      case PdfSplitRequest(:final input, :final ranges):
        final imgs = await _raster(input.bytes);
        final outputs = <PdfGenerationResult>[];
        for (final (i, range) in ranges.indexed) {
          final slice = <_Raster>[
            for (var p = range.start; p <= range.end; p++)
              if (p >= 1 && p <= imgs.length) imgs[p - 1],
          ];
          final bytes = await _compose(slice);
          outputs.add(PdfGenerationResult(
            bytes: bytes,
            fileName: 'split-${i + 1}.pdf',
            pageCount: slice.length,
            elapsed: DateTime.now().difference(started),
          ));
        }
        if (outputs.isEmpty) throw const ProcessingFailure(code: 'SPLIT_EMPTY', message: 'No pages matched the given ranges.');
        return PdfProcessingResult(outputs: outputs, operation: 'split');

      case PdfExtractPagesRequest(:final input, :final pages, :final fileName):
        final zero = pages.map((p) => p - 1).where((p) => p >= 0).toList();
        final imgs = await _raster(input.bytes, pages: zero);
        final bytes = await _compose(imgs);
        return _single(bytes, fileName, imgs.length, 'extractPages', started);

      case PdfRotatePagesRequest(:final input, :final pages, :final quarterTurns):
        final imgs = await _raster(input.bytes);
        final rotate = pages.isEmpty
            ? {for (var i = 0; i < imgs.length; i++) i}
            : pages.map((p) => p - 1).toSet();
        final bytes = await _compose(imgs, rotateTurns: quarterTurns, rotateIndices: rotate);
        return _single(bytes, 'rotated.pdf', imgs.length, 'rotate', started);

      case PdfWatermarkRequest(:final input, :final text, :final opacity):
        final imgs = await _raster(input.bytes);
        final bytes = await _compose(imgs, watermark: text ?? 'WATERMARK', opacity: opacity);
        return _single(bytes, 'watermarked.pdf', imgs.length, 'watermark', started);
    }
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

  Future<List<_Raster>> _raster(Uint8List bytes, {List<int>? pages}) async {
    final out = <_Raster>[];
    try {
      await for (final r in Printing.raster(bytes, pages: pages, dpi: rasterDpi)) {
        final png = await r.toPng();
        out.add(_Raster(png, r.width / rasterDpi * 72.0, r.height / rasterDpi * 72.0));
      }
    } catch (e) {
      throw ProcessingFailure(
        code: 'RASTER_FAILED',
        message: 'The input PDF could not be read for processing.',
        cause: e,
        recovery: 'Ensure the platform PDF backend is available, then retry.',
      );
    }
    if (out.isEmpty) {
      throw const ProcessingFailure(
        code: 'NO_PAGES',
        message: 'The input produced no pages.',
      );
    }
    return out;
  }

  Future<Uint8List> _compose(
    List<_Raster> images, {
    String? watermark,
    double opacity = 0.12,
    int rotateTurns = 0,
    Set<int>? rotateIndices,
  }) async {
    final doc = pw.Document();
    for (final (i, im) in images.indexed) {
      final turns = (rotateIndices == null || rotateIndices.contains(i)) ? rotateTurns : 0;
      final swap = turns.isOdd;
      final provider = pw.MemoryImage(im.png);
      doc.addPage(
        pw.Page(
          pageFormat: pdflib.PdfPageFormat(
            swap ? im.heightPt : im.widthPt,
            swap ? im.widthPt : im.heightPt,
          ),
          build: (context) {
            pw.Widget page = turns == 0
                ? pw.Image(provider, fit: pw.BoxFit.contain)
                : pw.Center(
                    child: pw.Transform.rotate(
                      angle: turns * math.pi / 2,
                      child: pw.Image(provider),
                    ),
                  );
            if (watermark == null) return page;
            return pw.Stack(
              fit: pw.StackFit.expand,
              alignment: pw.Alignment.center,
              children: [
                page,
                pw.Center(
                  child: pw.Opacity(
                    opacity: opacity.clamp(0.03, 0.4),
                    child: pw.Transform.rotate(
                      angle: math.pi / 4,
                      child: pw.Text(
                        watermark,
                        style: pw.TextStyle(
                            fontSize: 64,
                            color: pdflib.PdfColor.fromInt(0xFF787C84)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    return doc.save();
  }
}

class _Raster {
  const _Raster(this.png, this.widthPt, this.heightPt);
  final Uint8List png;
  final double widthPt;
  final double heightPt;
}
