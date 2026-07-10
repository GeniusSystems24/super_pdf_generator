// APPLICATION · high-level client. The single ergonomic entry point that
// composes the use cases, gateways and job queue. Constructed by the
// composition root — never news up infrastructure itself.

import 'dart:typed_data';

import '../domain/document.dart';
import '../domain/document_info.dart';
import '../domain/export.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/intelligence.dart';
import '../domain/jobs.dart';
import '../domain/printing.dart';
import '../domain/processing.dart';
import '../domain/security.dart';
import '../domain/sharing.dart';
import 'contracts.dart';
import 'jobs/job_queue.dart';
import 'usecases.dart';

class PdfClient {
  PdfClient({
    required GenerateDocument generate,
    required ProcessDocument process,
    required JobQueue jobs,
    required FileGateway fileGateway,
    required PrintGateway printGateway,
    ShareGateway? shareGateway,
    InspectDocument? inspect,
    PrinterDiscovery? printerDiscovery,
    EmailGateway? emailGateway,
    SecureDocument? secure,
    ExportDocument? export,
    AnalyzeDocument? analyze,
  })  : _generate = generate,
        _process = process,
        _jobs = jobs,
        _files = fileGateway,
        _print = printGateway,
        _share = shareGateway,
        _inspect = inspect,
        _discovery = printerDiscovery,
        _email = emailGateway,
        _secure = secure,
        _export = export,
        _analyze = analyze;

  final GenerateDocument _generate;
  final ProcessDocument _process;
  final JobQueue _jobs;
  final FileGateway _files;
  final PrintGateway _print;
  final ShareGateway? _share;
  final InspectDocument? _inspect;
  final PrinterDiscovery? _discovery;
  final EmailGateway? _email;
  final SecureDocument? _secure;
  final ExportDocument? _export;
  final AnalyzeDocument? _analyze;

  /// Job-management surface (enqueue / observe / retry / cancel / stats …).
  JobQueue get jobs => _jobs;

  bool get canShare => _share?.canShare ?? false;
  bool get canEmail => _email?.canEmail ?? false;
  bool get canDiscoverPrinters => _discovery != null;
  bool get canSecure => _secure != null;
  bool get canExport => _export != null;
  bool get canAnalyze => _analyze != null;

  /// Share targets the configured gateway can route to.
  Set<PdfShareTarget> get availableShareTargets =>
      _share?.availableTargets ?? const <PdfShareTarget>{};

  // ---- generation --------------------------------------------------------

  Future<Result<PdfGenerationResult>> generate(
    PdfGenerationRequest request, {
    void Function(PdfGenerationProgress)? onProgress,
  }) =>
      _generate(request, onProgress: onProgress);

  /// Generate and return only the raw bytes.
  Future<Result<Uint8List>> toBytes(PdfGenerationRequest request) async =>
      (await _generate(request)).map((r) => r.bytes);

  // ---- delivery ----------------------------------------------------------

  Future<Result<void>> download(PdfGenerationResult result) async {
    try {
      await _files.download(result);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(FileFailure(
        code: 'DOWNLOAD_FAILED',
        message: 'The file could not be downloaded.',
        cause: e,
      ),);
    }
  }

  Future<Result<PdfFileReference>> save(
    PdfGenerationResult result, {
    String? directory,
  }) async {
    try {
      return Result.ok(await _files.save(result, directory: directory));
    } catch (e) {
      return Result.err(FileFailure(
        code: 'SAVE_FAILED',
        message: 'The file could not be saved.',
        cause: e,
      ),);
    }
  }

  Future<Result<void>> printDocument(
    PdfGenerationResult result, {
    PrintSettings? settings,
    PrinterDevice? printer,
  }) async {
    try {
      await _print.printDocument(result, settings: settings, printer: printer);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(PrintingFailure(
        code: 'PRINT_FAILED',
        message: 'The document could not be sent to the printer.',
        cause: e,
      ),);
    }
  }

  /// Enumerate available printers, when a discovery adapter is configured.
  Future<Result<List<PrinterDevice>>> listPrinters() async {
    final discovery = _discovery;
    if (discovery == null) {
      return const Result.err(UnsupportedFeatureFailure(
        code: 'DISCOVERY_UNSUPPORTED',
        message: 'Printer discovery is not available on this client.',
      ),);
    }
    try {
      return Result.ok(await discovery.listPrinters());
    } catch (e) {
      return Result.err(PrintingFailure(
        code: 'DISCOVERY_FAILED',
        message: 'Printers could not be enumerated.',
        cause: e,
      ),);
    }
  }

  /// Open a pre-filled email compose window as a delivery channel.
  Future<Result<void>> emailCompose({
    List<String> to = const <String>[],
    String? subject,
    String? body,
    List<String> cc = const <String>[],
  }) async {
    final email = _email;
    if (email == null || !email.canEmail) {
      return const Result.err(UnsupportedFeatureFailure(
        code: 'EMAIL_UNSUPPORTED',
        message: 'Email is not available on this platform.',
        recovery: 'Use share() and pick an email target from the OS sheet.',
      ),);
    }
    try {
      await email.compose(to: to, subject: subject, body: body, cc: cc);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(SharingFailure(
        code: 'EMAIL_FAILED',
        message: 'The email could not be composed.',
        cause: e,
      ),);
    }
  }

  Future<Result<void>> share(PdfGenerationResult result, {String? subject}) async {
    final share = _share;
    if (share == null || !share.canShare) {
      return const Result.err(UnsupportedFeatureFailure(
        code: 'SHARE_UNSUPPORTED',
        message: 'Sharing is not available on this platform.',
        recovery: 'Use download or save instead.',
      ),);
    }
    try {
      await share.share(result, subject: subject);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(SharingFailure(
        code: 'SHARE_FAILED',
        message: 'The document could not be shared.',
        cause: e,
      ),);
    }
  }

  Future<Result<void>> shareTo(
    PdfGenerationResult result, {
    required PdfShareTarget target,
    String? subject,
  }) async {
    final share = _share;
    if (share == null || !share.canShare) {
      return const Result.err(UnsupportedFeatureFailure(
        code: 'SHARE_UNSUPPORTED',
        message: 'Sharing is not available on this platform.',
        recovery: 'Use download or save instead.',
      ),);
    }
    try {
      await share.shareTo(result, target: target, subject: subject);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(SharingFailure(
        code: 'SHARE_TO_FAILED',
        message: 'The document could not be shared to ${target.name}.',
        cause: e,
      ),);
    }
  }

  // ---- security ----------------------------------------------------------

  /// Encrypt a PDF and apply permission restrictions.
  Future<Result<PdfSecurityResult>> secure(PdfSecurityRequest request) {
    final secure = _secure;
    if (secure == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'SECURITY_UNSUPPORTED',
        message: 'Document security is not available on this client.',
        recovery: 'Use createStudioClient(), which wires the Syncfusion security service.',
      ),),);
    }
    return secure.protect(request);
  }

  /// Remove protection from an encrypted PDF, given its password.
  Future<Result<PdfSecurityResult>> unlock(PdfUnlockRequest request) {
    final secure = _secure;
    if (secure == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'SECURITY_UNSUPPORTED',
        message: 'Document security is not available on this client.',
        recovery: 'Use createStudioClient(), which wires the Syncfusion security service.',
      ),),);
    }
    return secure.unlock(request);
  }

  // ---- export ------------------------------------------------------------

  /// Convert an existing PDF into HTML, images, plain text or PDF/A.
  Future<Result<PdfExportResult>> export(PdfExportRequest request) {
    final export = _export;
    if (export == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'EXPORT_UNSUPPORTED',
        message: 'Export is not available on this client.',
        recovery: 'Use createStudioClient(), which wires the exporter.',
      ),),);
    }
    return export(request);
  }

  // ---- intelligence ------------------------------------------------------

  /// Analyze a document's structure and content (offline heuristics by default).
  Future<Result<PdfContentAnalysis>> analyze(PdfDocumentDefinition document) {
    final analyze = _analyze;
    if (analyze == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'ANALYSIS_UNSUPPORTED',
        message: 'Content analysis is not available on this client.',
      ),),);
    }
    return analyze(document);
  }

  /// Produce bilingual layout/content suggestions for a document.
  Future<Result<List<PdfLayoutSuggestion>>> suggestLayout(
    PdfDocumentDefinition document,
  ) {
    final analyze = _analyze;
    if (analyze == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'ANALYSIS_UNSUPPORTED',
        message: 'Content analysis is not available on this client.',
      ),),);
    }
    return analyze.suggest(document);
  }

  // ---- forms -------------------------------------------------------------

  /// Names of all fillable form fields in [document], in reading order.
  List<String> formFieldNames(PdfDocumentDefinition document) =>
      const FormFiller().fieldNames(document);

  /// Fill [document]'s interactive form fields from a map of field name ->
  /// value (String for text fields, bool for checkboxes). Returns a new,
  /// immutable document; ready to hand to [generate].
  PdfDocumentDefinition fillForm(
    PdfDocumentDefinition document,
    Map<String, Object?> values,
  ) =>
      const FormFiller().fill(document, values);

  // ---- processing --------------------------------------------------------

  Future<Result<PdfProcessingResult>> process(PdfProcessingRequest request) =>
      _process(request);

  /// Read metadata / page geometry from an existing PDF.
  Future<Result<PdfDocumentInfo>> inspect(PdfInputFile input) {
    final inspect = _inspect;
    if (inspect == null) {
      return Future.value(const Result.err(UnsupportedFeatureFailure(
        code: 'INSPECT_UNSUPPORTED',
        message: 'No PDF inspector is configured on this client.',
        recovery: 'Use createStudioClient(), which wires the Syncfusion inspector.',
      ),),);
    }
    return inspect(input);
  }

  // ---- background & batch ------------------------------------------------

  PdfJob enqueue(
    PdfGenerationRequest request, {
    PdfJobPriority priority = PdfJobPriority.normal,
    DateTime? schedule,
  }) =>
      _jobs.enqueue(request, priority: priority, schedule: schedule);

  String generateBatch(PdfBatchRequest batch) => _jobs.enqueueBatch(batch);

  Stream<PdfJobStatus> observeProgress(String jobId) => _jobs.observe(jobId);

  void cancel(String jobId) => _jobs.cancel(jobId);

  void dispose() => _jobs.dispose();
}
