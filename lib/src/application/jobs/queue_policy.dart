// APPLICATION · jobs · queue policy. Pure Dart.
//
// Decides the run order of pending jobs. Separated from the queue executor so
// the ordering strategy can be swapped without touching execution (SRP).

import '../../domain/jobs.dart';

/// Orders the pending jobs for execution.
abstract interface class QueuePolicy {
  /// Return [pending] in the order they should be dispatched.
  List<PdfJob> order(List<PdfJob> pending);
}

/// High → Normal → Low, then oldest-first within a priority (FIFO tiebreak).
class PriorityQueuePolicy implements QueuePolicy {
  const PriorityQueuePolicy();

  int _rank(PdfJobPriority p) => switch (p) {
        PdfJobPriority.high => 0,
        PdfJobPriority.normal => 1,
        PdfJobPriority.low => 2,
      };

  @override
  List<PdfJob> order(List<PdfJob> pending) {
    final list = List<PdfJob>.of(pending);
    list.sort((a, b) {
      final r = _rank(a.priority).compareTo(_rank(b.priority));
      return r != 0 ? r : a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }
}

/// Strict first-in-first-out, ignoring priority.
class FifoQueuePolicy implements QueuePolicy {
  const FifoQueuePolicy();
  @override
  List<PdfJob> order(List<PdfJob> pending) {
    final list = List<PdfJob>.of(pending)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}
