// COMPOSITION ROOT — the single place where concrete implementations meet.
//
// The Dart analogue of the Web design's `createPdfClient` / `createStudioClient`.
// Domain, application and presentation depend only on interfaces; this file
// wires the concretions. Everything is injectable, so tests supply fakes and
// apps swap the renderer, gateways or any job-queue policy without touching a
// line of application code.

import 'dart:typed_data';

import '../application/contracts.dart';
import '../application/jobs/job_queue.dart';
import '../application/jobs/job_repository.dart';
import '../application/jobs/progress_reporter.dart';
import '../application/jobs/queue_policy.dart';
import '../application/jobs/queue_statistics.dart';
import '../application/jobs/retry_policy.dart';
import '../application/jobs/scheduler.dart';
import '../application/pdf_client.dart';
import '../application/usecases.dart';
import '../infrastructure/platform/platform_gateways.dart';
import '../infrastructure/rendering/isolate_render_runner.dart';
import '../infrastructure/rendering/processing_renderer.dart';
import '../infrastructure/rendering/syncfusion_pdf_processor.dart';
import '../infrastructure/rendering/widget_pdf_renderer.dart';
import '../infrastructure/support.dart';

/// Build a [PdfClient] from injected adapters and policies. `renderer` is the
/// only required dependency; everything else has a sensible default.
PdfClient createPdfClient({
  required PdfRenderer renderer,
  FileGateway? fileGateway,
  PrintGateway? printGateway,
  ShareGateway? shareGateway,
  PdfLogger logger = const SilentPdfLogger(),
  QueuePolicy queuePolicy = const PriorityQueuePolicy(),
  RetryPolicy retryPolicy = const ExponentialRetryPolicy(),
  JobScheduler scheduler = const DueTimeScheduler(),
  ProgressReporter? progressReporter,
  QueueStatisticsCalculator statistics = const DefaultQueueStatistics(),
  JobRepository? jobRepository,
  int concurrency = 4,
  PdfInspector? inspector,
  PrinterDiscovery? printerDiscovery,
  EmailGateway? emailGateway,
}) {
  final generate = GenerateDocument(renderer, logger);
  final process = ProcessDocument(renderer, logger);

  final jobs = JobQueue(
    runner: generate.call,
    repository: jobRepository ?? InMemoryJobRepository(),
    queuePolicy: queuePolicy,
    retryPolicy: retryPolicy,
    scheduler: scheduler,
    progressReporter: progressReporter ?? StreamProgressReporter(),
    statistics: statistics,
    concurrency: concurrency,
  );

  return PdfClient(
    generate: generate,
    process: process,
    jobs: jobs,
    fileGateway: fileGateway ?? const SharePdfFileGateway(),
    printGateway: printGateway ?? const PrintingPrintGateway(),
    shareGateway: shareGateway ?? const PrintingShareGateway(),
    inspect: inspector == null ? null : InspectDocument(inspector, logger),
    printerDiscovery: printerDiscovery,
    emailGateway: emailGateway,
  );
}

/// A batteries-included client for Folio Studio and typical Flutter apps:
/// isolate-backed generation plus the platform print / share / file gateways.
/// Prefer [createPdfClient] with explicit adapters for tests or custom
/// platforms.
PdfClient createStudioClient({
  bool useIsolate = true,
  PdfLogger logger = const SilentPdfLogger(),
  int concurrency = 4,
  Uint8List? baseFontBytes,
  Uint8List? boldFontBytes,
  Uint8List? arabicFontBytes,
}) {
  final main = WidgetPdfRenderer(
    baseFontBytes: baseFontBytes,
    boldFontBytes: boldFontBytes,
    arabicFontBytes: arabicFontBytes,
  );
  final base = useIsolate ? IsolateRenderRunner(fallback: main) : main;
  // Lossless page-level processing + introspection via Syncfusion, layered on
  // top of the `pdf`/`printing` generation pipeline.
  const processor = SyncfusionPdfProcessor();
  final renderer = ProcessingRenderer(base: base, processor: processor);
  return createPdfClient(
    renderer: renderer,
    logger: logger,
    concurrency: concurrency,
    inspector: processor,
    printerDiscovery: const PrintingPrinterDiscovery(),
    emailGateway: const UrlLauncherEmailGateway(),
  );
}
