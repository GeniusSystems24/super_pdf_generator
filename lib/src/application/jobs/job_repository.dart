// APPLICATION · jobs · repository. Pure Dart.
//
// Persistence port for jobs plus an in-memory default. The queue reads and
// writes jobs only through this interface, so a durable (IndexedDB / sqflite /
// file) implementation can be injected later without changing the executor.

import 'dart:async';

import '../../domain/jobs.dart';

/// Stores the current state of every job.
abstract interface class JobRepository {
  PdfJob add(PdfJob job);
  PdfJob? byId(String id);
  List<PdfJob> all();
  List<PdfJob> byBatch(String batchId);
  void update(PdfJob job);
  void removeWhere(bool Function(PdfJob job) test);

  /// Emits the full job list whenever anything changes (drives the UI table).
  Stream<List<PdfJob>> watch();

  void dispose();
}

/// A simple in-memory repository suitable for the demo and tests.
class InMemoryJobRepository implements JobRepository {
  InMemoryJobRepository();

  final Map<String, PdfJob> _jobs = <String, PdfJob>{};
  final StreamController<List<PdfJob>> _changes =
      StreamController<List<PdfJob>>.broadcast();

  @override
  PdfJob add(PdfJob job) {
    _jobs[job.id] = job;
    _emit();
    return job;
  }

  @override
  PdfJob? byId(String id) => _jobs[id];

  @override
  List<PdfJob> all() => _jobs.values.toList(growable: false);

  @override
  List<PdfJob> byBatch(String batchId) =>
      _jobs.values.where((j) => j.batchId == batchId).toList(growable: false);

  @override
  void update(PdfJob job) {
    _jobs[job.id] = job;
    _emit();
  }

  @override
  void removeWhere(bool Function(PdfJob job) test) {
    _jobs.removeWhere((_, v) => test(v));
    _emit();
  }

  @override
  Stream<List<PdfJob>> watch() => _changes.stream;

  void _emit() {
    if (!_changes.isClosed) _changes.add(all());
  }

  @override
  void dispose() {
    if (!_changes.isClosed) _changes.close();
  }
}
