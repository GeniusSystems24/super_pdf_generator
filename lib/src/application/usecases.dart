// APPLICATION · use cases. Pure Dart orchestration over the domain + ports.
// Each is small and single-purpose (SRP) and returns a typed [Result] — never
// throws for expected conditions.

import '../domain/components.dart';
import '../domain/document.dart';
import '../domain/document_info.dart';
import '../domain/export.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/intelligence.dart';
import '../domain/processing.dart';
import '../domain/security.dart';
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
      ),);
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
          data: {'pages': render.pageCount, 'bytes': render.bytes.length},),);
      return Result.ok(PdfGenerationResult(
        bytes: render.bytes,
        fileName: request.fileName,
        pageCount: render.pageCount,
        elapsed: DateTime.now().difference(started),
      ),);
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
          data: {'outputs': result.outputs.length},),);
      return Result.ok(result);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(ProcessingFailure(
        code: 'PROCESS_FAILED',
        message: 'The ${request.operation} operation failed.',
        cause: e,
        context: {'stack': s.toString()},
      ),);
    }
  }
}

/// Read metadata / page geometry from an existing PDF.
class InspectDocument {
  const InspectDocument(this._inspector, this._logger);
  final PdfInspector _inspector;
  final PdfLogger _logger;

  Future<Result<PdfDocumentInfo>> call(PdfInputFile input) async {
    try {
      final info = await _inspector.inspect(input);
      _logger.log(LogEvent('info', 'inspected ${input.name}',
          data: {'pages': info.pageCount, 'bytes': info.byteLength},),);
      return Result.ok(info);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(ProcessingFailure(
        code: 'INSPECT_FAILED',
        message: 'The document could not be inspected.',
        cause: e,
        context: {'stack': s.toString()},
      ),);
    }
  }
}

/// Encrypt / decrypt a document and apply permission restrictions.
class SecureDocument {
  const SecureDocument(this._security, this._logger);
  final PdfSecurityService _security;
  final PdfLogger _logger;

  Future<Result<PdfSecurityResult>> protect(PdfSecurityRequest request) async {
    try {
      final result = await _security.protect(request);
      _logger.log(LogEvent('info', 'protected ${request.fileName}',
          data: request.options.toJson(),),);
      return Result.ok(result);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(SecurityFailure(
        code: 'PROTECT_FAILED',
        message: 'The document could not be encrypted.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Verify the input PDF is valid and not already protected.',
      ),);
    }
  }

  Future<Result<PdfSecurityResult>> unlock(PdfUnlockRequest request) async {
    try {
      final result = await _security.unlock(request);
      _logger.log(LogEvent('info', 'unlocked ${request.fileName}'));
      return Result.ok(result);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(SecurityFailure(
        code: 'UNLOCK_FAILED',
        message: 'The document could not be unlocked.',
        cause: e,
        context: {'stack': s.toString()},
        recovery: 'Check that the supplied password is correct.',
      ),);
    }
  }
}

/// Convert an existing PDF into another representation (HTML/image/text/PDF-A).
class ExportDocument {
  const ExportDocument(this._exporter, this._logger);
  final PdfExporter _exporter;
  final PdfLogger _logger;

  Future<Result<PdfExportResult>> call(PdfExportRequest request) async {
    try {
      final result = await _exporter.export(request);
      _logger.log(LogEvent('info', 'exported ${request.format.name}',
          data: {'artifacts': result.count},),);
      return Result.ok(result);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(ExportFailure(
        code: 'EXPORT_FAILED',
        message: 'The document could not be exported to ${request.format.name}.',
        cause: e,
        context: {'stack': s.toString()},
      ),);
    }
  }
}

/// Fill a document's interactive form fields from a map of field name -> value.
///
/// Pure and immutable: returns a new [PdfDocumentDefinition]. Text fields accept
/// a String value (rendered as a filled field); checkboxes accept a bool.
class FormFiller {
  const FormFiller();

  /// Every fillable field name present in [document], in reading order.
  List<String> fieldNames(PdfDocumentDefinition document) {
    final names = <String>[];
    void walk(PdfComponent c) {
      if (c is PdfFormField) names.add(c.name);
      if (c is PdfContainerBase) c.children.forEach(walk);
    }
    for (final p in document.pages) {
      p.content.forEach(walk);
    }
    return names;
  }

  /// Return a copy of [document] with matching fields filled from [values].
  PdfDocumentDefinition fill(
    PdfDocumentDefinition document,
    Map<String, Object?> values,
  ) {
    if (values.isEmpty) return document;
    final pages = document.pages
        .map((p) => p.copyWith(
            content: p.content.map((c) => _fill(c, values)).toList(),),)
        .toList();
    return document.copyWith(pages: pages);
  }

  PdfComponent _fill(PdfComponent c, Map<String, Object?> values) {
    switch (c) {
      case final PdfTextFormField f:
        return values.containsKey(f.name)
            ? f.withValue('${values[f.name]}')
            : f;
      case final PdfCheckboxField f:
        return values.containsKey(f.name)
            ? f.withChecked(values[f.name] == true)
            : f;
      case final PdfContainerBase container:
        return _rebuild(
            container, container.children.map((k) => _fill(k, values)).toList(),);
      default:
        return c;
    }
  }

  PdfComponent _rebuild(PdfContainerBase c, List<PdfComponent> kids) =>
      switch (c) {
        PdfContainer() => PdfContainer(kids),
        PdfRow() => PdfRow(kids),
        PdfColumn() => PdfColumn(kids),
        PdfStack() => PdfStack(kids),
        PdfWrap() => PdfWrap(kids),
        PdfGrid(:final columns) => PdfGrid(kids, columns: columns),
        PdfKeepTogether() => PdfKeepTogether(kids),
        PdfConditional(when: final condition) =>
          PdfConditional(when: condition, child: kids),
        PdfRepeated(:final count) => PdfRepeated(kids, count: count),
      };
}

/// Analyze a document's structure and content, and produce layout advice.
class AnalyzeDocument {
  const AnalyzeDocument(this._intelligence, this._logger);
  final PdfIntelligence _intelligence;
  final PdfLogger _logger;

  Future<Result<PdfContentAnalysis>> call(PdfDocumentDefinition document) async {
    try {
      final analysis = await _intelligence.analyze(document);
      _logger.log(LogEvent('info', 'analyzed document',
          data: analysis.toJson(),),);
      return Result.ok(analysis);
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(UnknownFailure(
        message: 'The document could not be analyzed.',
        cause: e,
        context: {'stack': s.toString()},
      ),);
    }
  }

  Future<Result<List<PdfLayoutSuggestion>>> suggest(
    PdfDocumentDefinition document,
  ) async {
    try {
      return Result.ok(await _intelligence.suggestLayout(document));
    } on PdfFailure catch (f) {
      return Result.err(f);
    } catch (e, s) {
      return Result.err(UnknownFailure(
        message: 'Layout suggestions could not be produced.',
        cause: e,
        context: {'stack': s.toString()},
      ),);
    }
  }
}
