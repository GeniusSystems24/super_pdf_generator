// APPLICATION · jobs · progress reporter. Pure Dart.
//
// Multiplexes per-job status/progress streams. The executor pushes ticks here;
// the UI (or `client.observeProgress(id)`) subscribes. Separated from the
// executor so progress transport is swappable (e.g. isolate SendPort bridge).

import 'dart:async';

import '../../domain/jobs.dart';

abstract interface class ProgressReporter {
  /// Push a status update for [jobId].
  void report(String jobId, PdfJobStatus status);

  /// Observe the status stream for [jobId].
  Stream<PdfJobStatus> observe(String jobId);

  void dispose();
}

/// Broadcast-stream backed reporter, one controller per observed job.
class StreamProgressReporter implements ProgressReporter {
  final Map<String, StreamController<PdfJobStatus>> _controllers =
      <String, StreamController<PdfJobStatus>>{};

  StreamController<PdfJobStatus> _controller(String id) =>
      _controllers.putIfAbsent(
          id, () => StreamController<PdfJobStatus>.broadcast(),);

  @override
  void report(String jobId, PdfJobStatus status) {
    final c = _controller(jobId);
    if (!c.isClosed) c.add(status);
  }

  @override
  Stream<PdfJobStatus> observe(String jobId) => _controller(jobId).stream;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      if (!c.isClosed) c.close();
    }
    _controllers.clear();
  }
}
