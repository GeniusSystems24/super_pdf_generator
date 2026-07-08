// APPLICATION · jobs · the queue facade + executor. Pure Dart.
//
// Composes the separated collaborators (repository, policy, retry, scheduler,
// progress reporter, statistics) into a concurrency-limited background queue.
// This is deliberately NOT a god object: every policy is injected and the
// actual generation is delegated to an injected [JobRunner] (wired to the
// GenerateDocument use case at the composition root), so the queue knows
// nothing about renderers, isolates or Flutter.

import 'dart:async';

import '../../domain/failures.dart';
import '../../domain/generation.dart';
import '../../domain/jobs.dart';
import 'job_repository.dart';
import 'progress_reporter.dart';
import 'queue_policy.dart';
import 'queue_statistics.dart';
import 'retry_policy.dart';
import 'scheduler.dart';

/// Runs a single generation request, forwarding progress ticks. Injected so
/// the queue depends on a function, not on the renderer.
typedef JobRunner = Future<Result<PdfGenerationResult>> Function(
  PdfGenerationRequest request, {
  void Function(PdfGenerationProgress progress)? onProgress,
});

/// A background job queue with bounded concurrency, priority ordering,
/// scheduled dispatch, retry-with-backoff and pause/resume.
class JobQueue {
  JobQueue({
    required JobRunner runner,
    JobRepository? repository,
    QueuePolicy queuePolicy = const PriorityQueuePolicy(),
    RetryPolicy retryPolicy = const ExponentialRetryPolicy(),
    JobScheduler scheduler = const DueTimeScheduler(),
    ProgressReporter? progressReporter,
    QueueStatisticsCalculator statistics = const DefaultQueueStatistics(),
    int concurrency = 4,
    DateTime Function()? clock,
  })  : _runner = runner,
        _repo = repository ?? InMemoryJobRepository(),
        _policy = queuePolicy,
        _retry = retryPolicy,
        _scheduler = scheduler,
        _reporter = progressReporter ?? StreamProgressReporter(),
        _stats = statistics,
        _concurrency = concurrency < 1 ? 1 : concurrency,
        _clock = clock ?? DateTime.now;

  final JobRunner _runner;
  final JobRepository _repo;
  final QueuePolicy _policy;
  final RetryPolicy _retry;
  final JobScheduler _scheduler;
  final ProgressReporter _reporter;
  final QueueStatisticsCalculator _stats;
  final int _concurrency;
  final DateTime Function() _clock;

  int _running = 0;
  bool _paused = false;
  int _seq = 0;
  final Set<String> _cancelled = <String>{};
  final List<Timer> _timers = <Timer>[];

  // ---- introspection (drives the Job Manager UI) -------------------------

  /// Full job list, emitted on every change.
  Stream<List<PdfJob>> watch() => _repo.watch();

  /// Current job snapshot.
  List<PdfJob> get jobs => _repo.all();

  /// Derived queue KPIs.
  QueueStatistics stats() => _stats.compute(_repo.all());

  /// Per-job status/progress stream.
  Stream<PdfJobStatus> observe(String jobId) => _reporter.observe(jobId);

  bool get isPaused => _paused;

  String _id(String prefix) =>
      '${prefix}_${_clock().microsecondsSinceEpoch.toRadixString(36)}_${_seq++}';

  // ---- enqueue -----------------------------------------------------------

  PdfJob enqueue(
    PdfGenerationRequest request, {
    PdfJobPriority priority = PdfJobPriority.normal,
    DateTime? schedule,
    String? batchId,
    String? label,
  }) {
    final job = PdfJob(
      id: _id('job'),
      label: label ?? request.fileName,
      request: request,
      priority: priority,
      createdAt: _clock(),
      scheduledFor: schedule,
      batchId: batchId,
    );
    _repo.add(job);
    _reporter.report(job.id, const JobPending());
    _pump();
    return job;
  }

  /// Enqueue every request in a batch under one shared batch id.
  String enqueueBatch(PdfBatchRequest batch) {
    final batchId = _id('batch');
    for (var i = 0; i < batch.requests.length; i++) {
      enqueue(
        batch.requests[i],
        priority: batch.priority,
        batchId: batchId,
        label: '${batch.label} · ${i + 1}',
      );
    }
    return batchId;
  }

  // ---- control -----------------------------------------------------------

  void retry(String jobId) {
    final job = _repo.byId(jobId);
    if (job == null) return;
    _cancelled.remove(jobId);
    _repo.update(job.copyWith(status: const JobPending()));
    _reporter.report(jobId, const JobPending());
    _pump();
  }

  void cancel(String jobId) {
    final job = _repo.byId(jobId);
    if (job == null) return;
    _cancelled.add(jobId);
    if (job.status is! JobRunning) {
      _repo.update(job.copyWith(status: const JobCancelled(), completedAt: _clock()));
      _reporter.report(jobId, const JobCancelled());
    }
  }

  void pauseQueue() => _paused = true;

  void resumeQueue() {
    _paused = false;
    _pump();
  }

  void clearCompleted() => _repo.removeWhere(
      (j) => j.status is JobCompleted || j.status is JobCancelled);

  // ---- executor ----------------------------------------------------------

  void _pump() {
    if (_paused) return;
    while (_running < _concurrency) {
      final next = _nextRunnable();
      if (next == null) break;
      _start(next);
    }
  }

  PdfJob? _nextRunnable() {
    final now = _clock();
    final pending = _repo
        .all()
        .where((j) =>
            j.status is JobPending &&
            !_cancelled.contains(j.id) &&
            _scheduler.isDue(j, now))
        .toList();
    if (pending.isEmpty) return null;
    return _policy.order(pending).first;
  }

  Future<void> _start(PdfJob job) async {
    _running++;
    final started = job.copyWith(status: const JobRunning(0), startedAt: _clock());
    _repo.update(started);
    _reporter.report(job.id, const JobRunning(0));
    try {
      final result = await _runner(
        job.request,
        onProgress: (p) {
          if (_cancelled.contains(job.id)) return;
          final j = _repo.byId(job.id);
          if (j != null) _repo.update(j.copyWith(status: JobRunning(p.fraction)));
          _reporter.report(job.id, JobRunning(p.fraction));
        },
      );
      if (_cancelled.contains(job.id)) {
        _finishCancelled(job.id);
      } else {
        result.fold(
          (value) {
            final done = (_repo.byId(job.id) ?? started)
                .copyWith(status: JobCompleted(value), completedAt: _clock());
            _repo.update(done);
            _reporter.report(job.id, JobCompleted(value));
          },
          (failure) => _onFailure(job.id, failure),
        );
      }
    } catch (e, s) {
      _onFailure(job.id, UnknownFailure.from(e, s));
    } finally {
      _running--;
      _pump();
    }
  }

  void _onFailure(String jobId, PdfFailure failure) {
    final job = _repo.byId(jobId);
    if (job == null) return;
    if (_retry.shouldRetry(job, failure)) {
      final attempt = job.retries;
      _repo.update(job.copyWith(status: const JobPending(), retries: job.retries + 1));
      _reporter.report(jobId, const JobPending());
      _timers.add(Timer(_retry.backoff(attempt), _pump));
    } else {
      _repo.update(job.copyWith(status: JobFailed(failure), completedAt: _clock()));
      _reporter.report(jobId, JobFailed(failure));
    }
  }

  void _finishCancelled(String jobId) {
    final job = _repo.byId(jobId);
    if (job == null) return;
    _repo.update(job.copyWith(status: const JobCancelled(), completedAt: _clock()));
    _reporter.report(jobId, const JobCancelled());
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _reporter.dispose();
    _repo.dispose();
  }
}
