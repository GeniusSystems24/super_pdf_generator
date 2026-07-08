// APPLICATION · use cases. Pure Dart orchestration over the domain + ports.
// Each is small and single-purpose (SRP) and returns a typed [Result] — never
// throws for expected conditions.

import '../domain/document.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/processing.dart';
import 'contracts.dart';

/// Generate a single document into bytes.
class GenerateDocument {
  const GenerateDocument(this._renderer, this._logger);
  final PdfRenderer _renderer;
  final PdfLogger _logger;

  Future<Result<PdfGenerationResult>> call(
    PdfGenerationRequest request, {
    void Function(PdfGenerationProgress)? onProgress,
  }) async {
    final issues = request.document.validate();
    final blocking = issues.where((i) => i.severity == 'error').toList();
    if (blocking.isNotEmpty) {
      return Result.err(ValidationFailure(
        code: 'DOCUMENT_INVALID',
        message: blocking.first.message,
        context: {'issues': issues.map((i) => i.message).toList()},
        recovery: 'Fix the reported validation issues and generate again.',
      ));
    }
    final started = DateTime.now();
    try {
      final render = await _renderer.render(
        PdfRenderRequest(
          document: request.document,
          processing: request.processing,
        ),
        PdfRenderContext(onProgress: onProgress),
      );
      _logger.log(LogEvent('info', 'generated ${request.fileName}',
          data: {'pages': render.pageCount, 'bytes': render.bytes.length}));
      return Result.ok(PdfGenerationResult(
        bytes: render.bytes,
        fileName: request.fileName,
        pageCount: render.pageCount,
        elapsed: DateTime.now().difference(started),
      ));
    } on PdfFailure catch (f) {
      _logger.log(LogEvent('error', f.code, data: f.toJson()));
      return Result.err(f);
    } catch (e, s) {
      final f = RenderingFailure(
        code: 'RENDER_FAILED',
        message: 'The document could not be rendered.',
        cause: e,
        recovery: 'Check the component tree and try again.',
        context: {'error': e.toString(), 'stack': s.toString()},
      );
      _logger.log(LogEvent('error', f.code, data: f.toJson()));
      return Result.err(f);
    }
  }
}

/// Run a processing operation (merge/split/extract/rotate/watermark).
class ProcessDocument {
  const ProcessDocument(this._renderer, this._logger);
  final PdfRenderer _renderer;
  final PdfLogger _logger;

  Future<Result<PdfProcessingResult>> call(PdfProcessingRequest request) async {
    try {
      final result = await _renderer.process(request);
      _logger.log(LogEvent('info', 'processed ${request.operation}',
          data: {'outputs': result.outputs.length}));
      return Result.ok(result);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(ProcessingFailure(
        code: 'PROCESS_FAILED',
        message: 'The ${request.operation} operation failed.',
        cause: e,
        context: {'stack': s.toString()},
      ));
    }
  }
}
