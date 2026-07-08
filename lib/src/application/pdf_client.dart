// APPLICATION · high-level client. The single ergonomic entry point that
// composes the use cases, gateways and job queue. Constructed by the
// composition root — never news up infrastructure itself.

import 'dart:typed_data';

import '../domain/document.dart';
import '../domain/document_info.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/jobs.dart';
import '../domain/printing.dart';
import '../domain/processing.dart';
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
  })  : _generate = generate,
        _process = process,
        _jobs = jobs,
        _files = fileGateway,
        _print = printGateway,
        _share = shareGateway,
        _inspect = inspect,
        _discovery = printerDiscovery,
        _email = emailGateway;

  final GenerateDocument _generate;
  final ProcessDocument _process;
  final JobQueue _jobs;
  final FileGateway _files;
  final PrintGateway _print;
  final ShareGateway? _share;
  final InspectDocument? _inspect;
  final PrinterDiscovery? _discovery;
  final EmailGateway? _email;

  /// Job-management surface (enqueue / observe / retry / cancel / stats …).
  JobQueue get jobs => _jobs;

  bool get canShare => _share?.canShare ?? false;
  bool get canEmail => _email?.canEmail ?? false;
  bool get canDiscoverPrinters => _discovery != null;

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
      ));
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
      ));
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
      ));
    }
  }

  /// Enumerate available printers, when a discovery adapter is configured.
  Future<Result<List<PrinterDevice>>> listPrinters() async {
    final discovery = _discovery;
    if (discovery == null) {
      return Result.err(const UnsupportedFeatureFailure(
        code: 'DISCOVERY_UNSUPPORTED',
        message: 'Printer discovery is not available on this client.',
      ));
    }
    try {
      return Result.ok(await discovery.listPrinters());
    } catch (e) {
      return Result.err(PrintingFailure(
        code: 'DISCOVERY_FAILED',
        message: 'Printers could not be enumerated.',
        cause: e,
      ));
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
      return Result.err(const UnsupportedFeatureFailure(
        code: 'EMAIL_UNSUPPORTED',
        message: 'Email is not available on this platform.',
        recovery: 'Use share() and pick an email target from the OS sheet.',
      ));
    }
    try {
      await email.compose(to: to, subject: subject, body: body, cc: cc);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(SharingFailure(
        code: 'EMAIL_FAILED',
        message: 'The email could not be composed.',
        cause: e,
      ));
    }
  }

  Future<Result<void>> share(PdfGenerationResult result, {String? subject}) async {
    final share = _share;
    if (share == null || !share.canShare) {
      return Result.err(const UnsupportedFeatureFailure(
        code: 'SHARE_UNSUPPORTED',
        message: 'Sharing is not available on this platform.',
        recovery: 'Use download or save instead.',
      ));
    }
    try {
      await share.share(result, subject: subject);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(SharingFailure(
        code: 'SHARE_FAILED',
        message: 'The document could not be shared.',
        cause: e,
      ));
    }
  }

  // ---- processing --------------------------------------------------------

  Future<Result<PdfProcessingResult>> process(PdfProcessingRequest request) =>
      _process(request);

  /// Read metadata / page geometry from an existing PDF.
  Future<Result<PdfDocumentInfo>> inspect(PdfInputFile input) {
    final inspect = _inspect;
    if (inspect == null) {
      return Future.value(Result.err(const UnsupportedFeatureFailure(
        code: 'INSPECT_UNSUPPORTED',
        message: 'No PDF inspector is configured on this client.',
        recovery: 'Use createStudioClient(), which wires the Syncfusion inspector.',
      )));
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
