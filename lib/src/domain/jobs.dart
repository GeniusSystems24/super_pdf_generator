// DOMAIN · jobs & batch. Pure Dart. Background generation is modelled as jobs
// with priority, retry accounting and a discriminated status.

import 'package:meta/meta.dart';

import 'generation.dart';

/// Job scheduling priority.
enum PdfJobPriority { low, normal, high }

/// The lifecycle status of a job — a discriminated union.
@immutable
sealed class PdfJobStatus {
  const PdfJobStatus();
  String get label;
}

class JobPending extends PdfJobStatus {
  const JobPending();
  @override
  String get label => 'pending';
}

class JobRunning extends PdfJobStatus {
  const JobRunning(this.progress);
  final double progress;
  @override
  String get label => 'running';
}

class JobCompleted extends PdfJobStatus {
  const JobCompleted(this.result);
  final PdfGenerationResult result;
  @override
  String get label => 'completed';
}

class JobFailed extends PdfJobStatus {
  const JobFailed(this.error);
  final Object error; // a PdfFailure
  @override
  String get label => 'failed';
}

class JobCancelled extends PdfJobStatus {
  const JobCancelled();
  @override
  String get label => 'cancelled';
}

class JobPaused extends PdfJobStatus {
  const JobPaused();
  @override
  String get label => 'paused';
}

/// An immutable job record. State transitions produce new instances via
/// [copyWith] — the repository holds the latest.
@immutable
class PdfJob {
  const PdfJob({
    required this.id,
    required this.label,
    required this.request,
    this.status = const JobPending(),
    this.priority = PdfJobPriority.normal,
    this.retries = 0,
    this.maxRetries = 3,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.scheduledFor,
    this.batchId,
  });

  final String id;
  final String label;
  final PdfGenerationRequest request;
  final PdfJobStatus status;
  final PdfJobPriority priority;
  final int retries;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? scheduledFor;
  final String? batchId;

  Duration? get duration => (startedAt != null && completedAt != null)
      ? completedAt!.difference(startedAt!)
      : null;

  bool get canRetry => retries < maxRetries;

  PdfJob copyWith({
    PdfJobStatus? status,
    int? retries,
    DateTime? startedAt,
    DateTime? completedAt,
  }) =>
      PdfJob(
        id: id,
        label: label,
        request: request,
        status: status ?? this.status,
        priority: priority,
        retries: retries ?? this.retries,
        maxRetries: maxRetries,
        createdAt: createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        scheduledFor: scheduledFor,
        batchId: batchId,
      );
}

/// A request to generate many documents as one batch.
@immutable
class PdfBatchRequest {
  const PdfBatchRequest({
    required this.requests,
    this.concurrency = 4,
    this.priority = PdfJobPriority.normal,
    this.label = 'batch',
  });

  final List<PdfGenerationRequest> requests;
  final int concurrency;
  final PdfJobPriority priority;
  final String label;
}

/// The aggregate result of a batch — per-item results in submission order.
@immutable
class PdfBatchResult {
  const PdfBatchResult({
    required this.batchId,
    required this.items,
  });

  final String batchId;
  final List<PdfJob> items;

  int get completed =>
      items.where((j) => j.status is JobCompleted).length;
  int get failed => items.where((j) => j.status is JobFailed).length;
  int get total => items.length;
}
