import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Batch Generation — maps a small dataset to documents and enqueues them as a
/// single batch through `client.generateBatch`, then shows live per-item
/// progress from the real queue. Concurrency is configurable.
class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key, required this.client, required this.builder});
  final PdfClient client;
  final BuilderController builder;

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  int _count = 24;
  String? _batchId;

  final _accounts = ['Northwind', 'Contoso', 'Fabrikam', 'Adventure', 'Wingtip', 'Tailspin'];

  void _run() {
    final requests = <PdfGenerationRequest>[];
    for (var i = 0; i < _count; i++) {
      final account = _accounts[i % _accounts.length];
      final doc = pdfDocument()
          .metadata(title: 'Statement ${1000 + i}', author: 'GeniusLink')
          .content([
        pdf.heading('Statement'),
        pdf.keyValue([MapEntry('Account', '$account #${1000 + i}'), const MapEntry('Period', 'Q4 2026')]),
        pdf.table(columns: const ['Date', 'Description', 'Amount'], rows: [
          ['2026-11-0${(i % 9) + 1}', 'Service charge', '${(i * 37) % 900 + 100}.00'],
          ['2026-11-1${i % 9}', 'Subscription', '${(i * 19) % 500 + 50}.00'],
        ]),
      ]).build();
      requests.add(PdfGenerationRequest(fileName: 'statement-${1000 + i}.pdf', document: doc));
    }
    final id = widget.client.generateBatch(PdfBatchRequest(requests: requests, label: 'statements'));
    setState(() => _batchId = id);
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
          child: Row(children: [
            const GlEyebrow('Process · Batch generation'),
            const Spacer(),
            Text('Count', style: GlType.body(context, size: 12, color: gl.fg3)),
            const SizedBox(width: 10),
            GlSegmented<int>(value: _count, segments: const {12: '12', 24: '24', 60: '60'}, onChanged: (v) => setState(() => _count = v)),
            const SizedBox(width: 14),
            GlPrimaryButton(label: 'Generate $_count docs', icon: Icons.layers_rounded, onPressed: _run),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<PdfJob>>(
            stream: widget.client.jobs.watch(),
            initialData: widget.client.jobs.jobs,
            builder: (context, snapshot) {
              final all = snapshot.data ?? const <PdfJob>[];
              final items = _batchId == null ? const <PdfJob>[] : all.where((j) => j.batchId == _batchId).toList();
              final done = items.where((j) => j.status is JobCompleted).length;
              final running = items.where((j) => j.status is JobRunning).length;
              final failed = items.where((j) => j.status is JobFailed).length;
              final pending = items.where((j) => j.status is JobPending).length;
              final progress = items.isEmpty ? 0.0 : done / items.length;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_batchId == null)
                    _Intro()
                  else ...[
                    GlCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            GlSectionMarker(gl.green),
                            const SizedBox(width: 10),
                            Text('Batch run', style: GlType.body(context, size: 13, weight: FontWeight.w700, color: gl.fg1)),
                            const SizedBox(width: 10),
                            GlStatusPill(progress >= 1 ? 'COMPLETE' : 'RUNNING', color: progress >= 1 ? gl.green : gl.accent),
                            const Spacer(),
                            Text('$done / ${items.length}', style: GlType.mono(context, size: 12, color: gl.fg2)),
                          ]),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: GlRadius.pill,
                            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: gl.input, color: gl.accent),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            _stat(context, '$done', 'completed', gl.green),
                            _stat(context, '$running', 'running', gl.accent),
                            _stat(context, '$pending', 'pending', gl.fg3),
                            _stat(context, '$failed', 'failed', failed == 0 ? gl.fg3 : gl.danger),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, j) in items.take(12).indexed) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(children: [
                                Expanded(child: Text(j.label, style: GlType.mono(context, size: 11.5, color: gl.fg1))),
                                _jobPill(context, j.status),
                              ]),
                            ),
                            if (i < items.take(12).length - 1) Divider(height: 1, color: gl.border),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String v, String l, Color c) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: context.gl.input, borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: context.gl.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: GlType.mono(context, size: 18, color: c, weight: FontWeight.w700)),
            Text(l, style: GlType.body(context, size: 9.5, color: context.gl.fg3)),
          ]),
        ),
      );

  Widget _jobPill(BuildContext context, PdfJobStatus s) {
    final gl = context.gl;
    return switch (s) {
      JobCompleted() => GlStatusPill('DONE', color: gl.green),
      JobRunning() => GlStatusPill('RUN', color: gl.accent),
      JobFailed() => GlStatusPill('FAIL', color: gl.danger),
      JobPending() => GlStatusPill('QUEUED', color: gl.fg3),
      _ => GlStatusPill(s.label.toUpperCase(), color: gl.fg3),
    };
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return GlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlSectionHeader(markerColor: gl.green, title: 'Batch generation', subtitle: 'Map a dataset → documents → queue'),
        const SizedBox(height: 14),
        Text('Choose a count and press Generate. Studio maps each row to a document definition and enqueues them as one batch through the real job queue — with bounded concurrency, live progress, retry and cancellation. Failed items stay in the batch group and are retryable in the Job Manager.',
            style: GlType.body(context, size: 13, color: gl.fg2).copyWith(height: 1.55)),
      ]),
    );
  }
}
