// APPLICATION · jobs · retry policy. Pure Dart.
//
// Decides whether a failed job should be retried and how long to wait before
// the next attempt. Kept separate from the executor so retry behaviour is a
// pluggable strategy (SRP / OCP).

import '../../domain/failures.dart';
import '../../domain/jobs.dart';

abstract interface class RetryPolicy {
  /// Whether [job] should be retried after [failure].
  bool shouldRetry(PdfJob job, PdfFailure failure);

  /// Delay before the retry numbered [attempt] (0-based).
  Duration backoff(int attempt);
}

/// Exponential backoff, capped, gated on the failure being retryable and the
/// job's own [PdfJob.maxRetries] budget.
class ExponentialRetryPolicy implements RetryPolicy {
  const ExponentialRetryPolicy({
    this.base = const Duration(milliseconds: 200),
    this.max = const Duration(seconds: 10),
    this.maxAttempts = 3,
  });

  final Duration base;
  final Duration max;
  final int maxAttempts;

  @override
  bool shouldRetry(PdfJob job, PdfFailure failure) =>
      failure.retryable && job.retries < job.maxRetries && job.retries < maxAttempts;

  @override
  Duration backoff(int attempt) {
    final ms = base.inMilliseconds * (1 << attempt);
    return Duration(milliseconds: ms.clamp(0, max.inMilliseconds));
  }
}

/// Never retries — every failure is terminal.
class NoRetryPolicy implements RetryPolicy {
  const NoRetryPolicy();
  @override
  bool shouldRetry(PdfJob job, PdfFailure failure) => false;
  @override
  Duration backoff(int attempt) => Duration.zero;
}
