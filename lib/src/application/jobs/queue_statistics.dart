// APPLICATION · jobs · statistics. Pure Dart.
//
// Derives queue KPIs from the current job list. A pure function behind an
// interface so the dashboard/job-manager read a stable shape.

import '../../domain/jobs.dart';

/// A snapshot of queue health.
class QueueStatistics {
  const QueueStatistics({
    this.pending = 0,
    this.running = 0,
    this.completed = 0,
    this.failed = 0,
    this.paused = 0,
    this.cancelled = 0,
    this.averageDuration = Duration.zero,
  });

  final int pending;
  final int running;
  final int completed;
  final int failed;
  final int paused;
  final int cancelled;
  final Duration averageDuration;

  int get total =>
      pending + running + completed + failed + paused + cancelled;

  int get averageMs => averageDuration.inMilliseconds;
}

abstract interface class QueueStatisticsCalculator {
  QueueStatistics compute(List<PdfJob> jobs);
}

class DefaultQueueStatistics implements QueueStatisticsCalculator {
  const DefaultQueueStatistics();

  @override
  QueueStatistics compute(List<PdfJob> jobs) {
    var pending = 0, running = 0, completed = 0, failed = 0, paused = 0, cancelled = 0;
    var durMs = 0, durCount = 0;
    for (final j in jobs) {
      switch (j.status) {
        case JobPending():
          pending++;
        case JobRunning():
          running++;
        case JobCompleted():
          completed++;
        case JobFailed():
          failed++;
        case JobPaused():
          paused++;
        case JobCancelled():
          cancelled++;
      }
      final d = j.duration;
      if (d != null) {
        durMs += d.inMilliseconds;
        durCount++;
      }
    }
    return QueueStatistics(
      pending: pending,
      running: running,
      completed: completed,
      failed: failed,
      paused: paused,
      cancelled: cancelled,
      averageDuration:
          Duration(milliseconds: durCount == 0 ? 0 : (durMs ~/ durCount)),
    );
  }
}
