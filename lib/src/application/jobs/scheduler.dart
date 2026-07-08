// APPLICATION · jobs · scheduler. Pure Dart.
//
// Answers "is this job due to run yet?" — the seam for scheduled generation.
// Separated so a cron-like or business-calendar scheduler can replace the
// default without touching the queue.

import '../../domain/jobs.dart';

abstract interface class JobScheduler {
  bool isDue(PdfJob job, DateTime now);
}

/// A job is due when it has no scheduled time, or that time has arrived.
class DueTimeScheduler implements JobScheduler {
  const DueTimeScheduler();

  @override
  bool isDue(PdfJob job, DateTime now) =>
      job.scheduledFor == null || !job.scheduledFor!.isAfter(now);
}
