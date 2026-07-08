// INFRASTRUCTURE · rendering · processing renderer (decorator).
//
// Composes a base [PdfRenderer] (which owns `render`) with a lossless
// [SyncfusionPdfProcessor] (which owns `process`). Generation keeps using the
// `pdf`/`printing` pipeline — optionally off-isolate — while page-level
// processing runs losslessly through Syncfusion on the main isolate.

import '../../application/contracts.dart';
import '../../domain/generation.dart';
import '../../domain/processing.dart';
import 'syncfusion_pdf_processor.dart';

class ProcessingRenderer implements PdfRenderer {
  const ProcessingRenderer({
    required PdfRenderer base,
    SyncfusionPdfProcessor processor = const SyncfusionPdfProcessor(),
  })  : _base = base,
        _processor = processor;

  final PdfRenderer _base;
  final SyncfusionPdfProcessor _processor;

  @override
  Future<PdfRenderResult> render(PdfRenderRequest request, [PdfRenderContext? context]) =>
      _base.render(request, context);

  @override
  Future<PdfProcessingResult> process(PdfProcessingRequest request) =>
      _processor.process(request);
}
