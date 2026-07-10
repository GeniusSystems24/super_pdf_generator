import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Job Manager — monitors and controls the real queue. Reads live via
/// `client.jobs.watch()`; retry / cancel / pause / resume / clear all call
/// through to the separated queue collaborators. A details drawer inspects the
/// selected job, including a typed failure when present.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.client});
  final PdfClient client;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _filter = 'all';
  String? _selectedId;
  bool _paused = false;

  bool _matches(PdfJob j) => switch (_filter) {
        'running' => j.status is JobRunning,
        'failed' => j.status is JobFailed,
        'completed' => j.status is JobCompleted,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return StreamBuilder<List<PdfJob>>(
      stream: widget.client.jobs.watch(),
      initialData: widget.client.jobs.jobs,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <PdfJob>[];
        final stats = widget.client.jobs.stats();
        final rows = all.where(_matches).toList().reversed.toList();
        PdfJob? selected;
        if (_selectedId != null) {
          for (final j in all) {
            if (j.id == _selectedId) {
              selected = j;
              break;
            }
          }
        }
        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  // toolbar
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                    child: Row(children: [
                      Text('Job Queue', style: GlType.body(context, size: 13, weight: FontWeight.w700, color: gl.fg1)),
                      const Spacer(),
                      GlGhostButton(
                        label: _paused ? 'Resume queue' : 'Pause queue',
                        icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        onPressed: () {
                          setState(() => _paused = !_paused);
                          _paused ? widget.client.jobs.pauseQueue() : widget.client.jobs.resumeQueue();
                        },
                      ),
                      const SizedBox(width: 8),
                      GlGhostButton(label: 'Clear completed', icon: Icons.cleaning_services_outlined, onPressed: widget.client.jobs.clearCompleted),
                    ]),
                  ),
                  // stats strip
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(children: [
                      _stat(context, '${stats.pending}', 'Pending', gl.fg3),
                      _stat(context, '${stats.running}', 'Running', gl.accent),
                      _stat(context, '${stats.completed}', 'Completed', gl.green),
                      _stat(context, '${stats.failed}', 'Failed', gl.danger),
                      _stat(context, '${stats.paused}', 'Paused', gl.orange),
                      _stat(context, '${stats.averageMs}ms', 'Avg time', gl.fg3),
                    ]),
                  ),
                  // filter tabs
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                    child: Row(children: [
                      for (final f in ['all', 'running', 'failed', 'completed'])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _Tab(label: f, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                        ),
                    ]),
                  ),
                  // header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                    child: Row(children: [
                      Expanded(flex: 4, child: Text('JOB', style: GlType.label(context).copyWith(fontSize: 9.5))),
                      Expanded(flex: 2, child: Text('PRIORITY', style: GlType.label(context).copyWith(fontSize: 9.5))),
                      Expanded(flex: 2, child: Text('RETRY', style: GlType.label(context).copyWith(fontSize: 9.5))),
                      Expanded(flex: 3, child: Text('PROGRESS', style: GlType.label(context).copyWith(fontSize: 9.5))),
                      Expanded(flex: 2, child: Text('STATUS', style: GlType.label(context).copyWith(fontSize: 9.5), textAlign: TextAlign.right)),
                    ]),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text('No jobs yet — generate a batch to populate the queue.', style: GlType.body(context, size: 12.5, color: gl.fg3)))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: gl.border),
                            itemBuilder: (context, i) => _JobRow(
                              job: rows[i],
                              selected: rows[i].id == _selectedId,
                              onTap: () => setState(() => _selectedId = rows[i].id),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (selected != null)
              Container(
                width: 250,
                decoration: BoxDecoration(border: Border(left: BorderSide(color: gl.border)), color: gl.surface),
                child: _Drawer(
                  job: selected,
                  onRetry: () => widget.client.jobs.retry(selected!.id),
                  onCancel: () => widget.client.jobs.cancel(selected!.id),
                  onClose: () => setState(() => _selectedId = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, String v, String l, Color c) => Padding(
        padding: const EdgeInsets.only(right: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: GlType.mono(context, size: 17, color: c, weight: FontWeight.w700)),
          Text(l, style: GlType.body(context, size: 9.5, color: context.gl.fg3)),
        ]),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: selected ? gl.hover : Colors.transparent, borderRadius: const BorderRadius.all(GlRadius.md)),
        child: Text(label[0].toUpperCase() + label.substring(1),
            style: GlType.body(context, size: 11.5, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? gl.fg1 : gl.fg3)),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.selected, required this.onTap});
  final PdfJob job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final isFail = job.status is JobFailed;
    final progress = job.status is JobRunning ? (job.status as JobRunning).progress : (job.status is JobCompleted ? 1.0 : 0.0);
    return Material(
      color: selected ? gl.hover : (isFail ? gl.danger.withValues(alpha:0.05) : Colors.transparent),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(children: [
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job.label, style: GlType.mono(context, size: 11.5, color: gl.fg1), overflow: TextOverflow.ellipsis),
                Text(isFail ? 'failure · tap for details' : (job.batchId != null ? 'batch item' : 'generate'),
                    style: GlType.body(context, size: 9.5, color: isFail ? gl.danger : gl.fg4)),
              ]),
            ),
            Expanded(flex: 2, child: _priority(context, job.priority)),
            Expanded(flex: 2, child: Text('${job.retries}/${job.maxRetries}', style: GlType.mono(context, size: 11, color: job.retries > 0 ? gl.orange : gl.fg3))),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: GlRadius.pill,
                  child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: gl.input, color: isFail ? gl.danger : gl.accent),
                ),
              ),
            ),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _statusPill(context, job.status))),
          ]),
        ),
      ),
    );
  }

  Widget _priority(BuildContext context, PdfJobPriority p) {
    final gl = context.gl;
    final (label, color) = switch (p) {
      PdfJobPriority.high => ('HIGH', gl.danger),
      PdfJobPriority.normal => ('NORMAL', gl.orange),
      PdfJobPriority.low => ('LOW', gl.fg3),
    };
    return Align(alignment: Alignment.centerLeft, child: GlStatusPill(label, color: color));
  }

  Widget _statusPill(BuildContext context, PdfJobStatus s) {
    final gl = context.gl;
    return switch (s) {
      JobCompleted() => GlStatusPill('DONE', color: gl.green),
      JobRunning() => GlStatusPill('RUN', color: gl.accent),
      JobFailed() => GlStatusPill('FAIL', color: gl.danger),
      JobPending() => GlStatusPill('PEND', color: gl.fg3),
      JobPaused() => GlStatusPill('PAUSE', color: gl.orange),
      JobCancelled() => GlStatusPill('CXL', color: gl.fg3),
    };
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({required this.job, required this.onRetry, required this.onCancel, required this.onClose});
  final PdfJob job;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final failure = job.status is JobFailed ? (job.status as JobFailed).error : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
          child: Row(children: [
            GlSectionMarker(failure != null ? gl.danger : gl.accent),
            const SizedBox(width: 10),
            Expanded(child: Text('Job details', style: GlType.body(context, size: 13, weight: FontWeight.w700, color: gl.fg1))),
            GestureDetector(onTap: onClose, child: Icon(Icons.close_rounded, size: 16, color: gl.fg3)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(job.label, style: GlType.mono(context, size: 12, color: gl.fg1)),
              const SizedBox(height: 3),
              Text('${job.id} · ${job.priority.name}', style: GlType.mono(context, size: 10, color: gl.fg4)),
              const SizedBox(height: 16),
              _kv(context, 'Status', job.status.label),
              _kv(context, 'Retries', '${job.retries} / ${job.maxRetries}'),
              _kv(context, 'Created', _t(job.createdAt)),
              if (job.duration != null) _kv(context, 'Duration', '${job.duration!.inMilliseconds}ms'),
              if (failure is PdfFailure) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: gl.danger.withValues(alpha:0.07), borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: gl.danger.withValues(alpha:0.26))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(failure.code, style: GlType.mono(context, size: 10.5, color: gl.danger, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(failure.message, style: GlType.body(context, size: 11, color: gl.fg2).copyWith(height: 1.5)),
                    if (failure.recovery != null) ...[
                      const SizedBox(height: 8),
                      Text('RECOVERY', style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 8.5)),
                      const SizedBox(height: 3),
                      Text(failure.recovery!, style: GlType.body(context, size: 11, color: gl.fg2).copyWith(height: 1.5)),
                    ],
                  ]),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: gl.border))),
          child: Row(children: [
            Expanded(child: GlPrimaryButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry)),
            const SizedBox(width: 8),
            Expanded(child: GlGhostButton(label: 'Cancel', onPressed: onCancel)),
          ]),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: GlType.body(context, size: 11.5, color: context.gl.fg3)),
          Text(v, style: GlType.mono(context, size: 11, color: context.gl.fg2)),
        ]),
      );

  String _t(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}
