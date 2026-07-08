// INFRASTRUCTURE · rendering · isolate runner.
//
// Wraps a [PdfRenderer] so generation runs off the main isolate (the Flutter
// analogue of the Web design's Web-Worker generation). Because a document
// definition is serializable, it crosses the isolate boundary as plain JSON;
// the render executes in a background isolate via `Isolate.run` and returns
// transferable bytes. Any failure (or an unsupported platform such as web,
// where `Isolate.run` is not available) falls back to main-isolate rendering —
// same API, same result type.

import 'dart:isolate';

import '../../application/contracts.dart';
import '../../domain/generation.dart';
import '../../domain/processing.dart';
import 'pw_mapper.dart';
import 'widget_pdf_renderer.dart';

class IsolateRenderRunner implements PdfRenderer {
  IsolateRenderRunner({WidgetPdfRenderer? fallback, this.preferIsolate = true})
      : _delegate = fallback ?? WidgetPdfRenderer();

  final WidgetPdfRenderer _delegate;
  final bool preferIsolate;

  @override
  Future<PdfRenderResult> render(PdfRenderRequest request,
      [PdfRenderContext? context]) async {
    // Custom fonts are held by the main-isolate delegate and are not sent
    // across the boundary, so fall back to the delegate when they are set.
    final hasCustomFonts = _delegate.baseFontBytes != null ||
        _delegate.boldFontBytes != null ||
        _delegate.arabicFontBytes != null;

    if (preferIsolate && !hasCustomFonts) {
      context?.onProgress?.call(
          const PdfGenerationProgress(fraction: 0.1, note: 'dispatching to isolate'));
      try {
        final documentJson = request.document.toJson();
        final processingJson = request.processing.toJson();
        final (bytes, pages) = await Isolate.run(
            () => renderDocumentJson(documentJson, processingJson));
        context?.onProgress?.call(const PdfGenerationProgress(fraction: 1, note: 'done'));
        return PdfRenderResult(bytes: bytes, pageCount: pages);
      } catch (_) {
        // Unsupported platform or isolate error — degrade gracefully.
      }
    }
    return _delegate.render(request, context);
  }

  @override
  Future<PdfProcessingResult> process(PdfProcessingRequest request) =>
      _delegate.process(request); // rasterization requires the main isolate
}
