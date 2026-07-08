// TEST · application — job queue behaviour (run, retry, cancel, priority).
//
// The queue is exercised with an injected fake [JobRunner], so these tests are
// fast and need no renderer, Flutter binding or pdf engine.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

PdfGenerationRequest _req([String name = 'a.pdf']) => PdfGenerationRequest(
      fileName: name,
      document: pdfDocument().metadata(title: name).content([pdf.paragraph('x')]).build(),
    );

PdfGenerationResult _ok(String name) => PdfGenerationResult(
      bytes: Uint8List(0),
      fileName: name,
      pageCount: 1,
      elapsed: Duration.zero,
    );

void main() {
  group('JobQueue', () {
    test('runs an enqueued job to completion', () async {
      final queue = JobQueue(
        runner: (request, {onProgress}) async {
          onProgress?.call(const PdfGenerationProgress(fraction: 0.5));
          return Result.ok(_ok(request.fileName));
        },
      );
      final job = queue.enqueue(_req());
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final updated = queue.jobs.firstWhere((j) => j.id == job.id);
      expect(updated.status, isA<JobCompleted>());
      queue.dispose();
    });

    test('retries a retryable failure, then succeeds', () async {
      var attempts = 0;
      final queue = JobQueue(
        retryPolicy: const ExponentialRetryPolicy(base: Duration(milliseconds: 5)),
        runner: (request, {onProgress}) async {
          attempts++;
          if (attempts < 2) {
            return Result.err(const FontFailure(code: 'F', message: 'font missing'));
          }
          return Result.ok(_ok(request.fileName));
        },
      );
      final job = queue.enqueue(_req('retry.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(attempts, greaterThanOrEqualTo(2));
      expect(queue.jobs.firstWhere((j) => j.id == job.id).status, isA<JobCompleted>());
      queue.dispose();
    });

    test('does not retry a non-retryable failure', () async {
      final queue = JobQueue(
        runner: (request, {onProgress}) async =>
            Result.err(const ValidationFailure(code: 'V', message: 'bad')),
      );
      final job = queue.enqueue(_req('bad.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(queue.jobs.firstWhere((j) => j.id == job.id).status, isA<JobFailed>());
      queue.dispose();
    });

    test('cancelling a pending job marks it cancelled', () async {
      final queue = JobQueue(runner: (request, {onProgress}) async => Result.ok(_ok(request.fileName)));
      queue.pauseQueue();
      final job = queue.enqueue(_req('c.pdf'));
      queue.cancel(job.id);
      expect(queue.jobs.firstWhere((j) => j.id == job.id).status, isA<JobCancelled>());
      queue.dispose();
    });

    test('statistics reflect completed jobs', () async {
      final queue = JobQueue(runner: (request, {onProgress}) async => Result.ok(_ok(request.fileName)));
      queue.enqueue(_req('1.pdf'));
      queue.enqueue(_req('2.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final stats = queue.stats();
      expect(stats.completed, 2);
      queue.dispose();
    });
  });

  group('PriorityQueuePolicy', () {
    test('orders high → normal → low, FIFO within a priority', () {
      final base = DateTime(2026, 1, 1);
      PdfJob job(String id, PdfJobPriority p, int offset) => PdfJob(
            id: id,
            label: id,
            request: _req(id),
            priority: p,
            createdAt: base.add(Duration(milliseconds: offset)),
          );
      final ordered = const PriorityQueuePolicy().order([
        job('n', PdfJobPriority.normal, 0),
        job('h', PdfJobPriority.high, 10),
        job('l', PdfJobPriority.low, 0),
        job('h2', PdfJobPriority.high, 0),
      ]);
      expect(ordered.map((j) => j.id).toList(), ['h2', 'h', 'n', 'l']);
    });
  });
}
