// APPLICATION · high-level client. The single ergonomic entry point that
// composes the use cases, gateways and job queue. Constructed by the
// composition root — never news up infrastructure itself.

import 'dart:typed_data';

import '../domain/document.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/jobs.dart';
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
  })  : _generate = generate,
        _process = process,
        _jobs = jobs,
        _files = fileGateway,
        _print = printGateway,
        _share = shareGateway;

  final GenerateDocument _generate;
  final ProcessDocument _process;
  final JobQueue _jobs;
  final FileGateway _files;
  final PrintGateway _print;
  final ShareGateway? _share;

  /// Job-management surface (enqueue / observe / retry / cancel / stats …).
  JobQueue get jobs => _jobs;

  bool get canShare => _share?.canShare ?? false;

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

  Future<Result<void>> printDocument(PdfGenerationResult result) async {
    try {
      await _print.printDocument(result);
      return const Result.ok(null);
    } catch (e) {
      return Result.err(PrintingFailure(
        code: 'PRINT_FAILED',
        message: 'The document could not be sent to the printer.',
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
