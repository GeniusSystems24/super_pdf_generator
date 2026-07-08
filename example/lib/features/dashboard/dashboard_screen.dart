import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Overview screen: system status, KPIs, recent output and live queue — the
/// entry point mirroring the approved Web dashboard.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.client,
    required this.builder,
    required this.onNavigate,
  });

  final PdfClient client;
  final BuilderController builder;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return StreamBuilder<List<PdfJob>>(
      stream: client.jobs.watch(),
      initialData: client.jobs.jobs,
      builder: (context, snapshot) {
        final stats = client.jobs.stats();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GlEyebrow('Overview'),
                      const SizedBox(height: 4),
                      Text('Good morning', style: GlType.display(context, size: 26)),
                      const SizedBox(height: 4),
                      Text('Folio is ready. The web-canvas renderer and a 4-worker isolate pool are online.',
                          style: GlType.body(context, size: 13, color: gl.fg3)),
                    ],
                  ),
                ),
                GlPrimaryButton(
                  label: 'New Document',
                  icon: Icons.add_rounded,
                  onPressed: () => onNavigate('Document Builder'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // KPI row
            Row(
              children: [
                Expanded(child: GlStatCard(label: 'Docs generated · 24h', value: '1,284', sub: '+12.4% vs. yesterday', subColor: gl.green)),
                const SizedBox(width: 12),
                Expanded(child: GlStatCard(label: 'Avg generate time', value: '142ms', sub: '−18ms · worker pool', subColor: gl.green)),
                const SizedBox(width: 12),
                Expanded(child: GlStatCard(label: 'Active jobs', value: '${stats.running + stats.pending}', sub: '${stats.running} running · ${stats.pending} pending')),
                const SizedBox(width: 12),
                Expanded(child: GlStatCard(label: 'Failures · 24h', value: '${stats.failed}', sub: stats.failed == 0 ? 'all clear' : 'see error inspector', subColor: stats.failed == 0 ? gl.green : gl.danger)),
              ],
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _RecentGenerations(onOpen: () => onNavigate('PDF Preview'))),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _QueuePanel(jobs: snapshot.data ?? const [])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentGenerations extends StatelessWidget {
  const _RecentGenerations({required this.onOpen});
  final VoidCallback onOpen;

  static const _rows = [
    ('invoice-INV-2042.pdf', '86 KB', '2', 'DONE'),
    ('statement-Q4-ar.pdf', '214 KB', '7', 'DONE'),
    ('report-monthly.pdf', '1.2 MB', '24', 'GENERATING'),
    ('certificate-0031.pdf', '—', '1', 'FONT ✕'),
    ('receipt-8841.pdf', '42 KB', '1', 'DONE'),
  ];

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    Color toneFor(String s) => switch (s) {
          'DONE' => gl.green,
          'GENERATING' => gl.accent,
          _ => gl.danger,
        };
    return GlCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
            child: GlSectionHeader(
              markerColor: gl.accent,
              title: 'Recent Generations',
              trailing: GestureDetector(onTap: onOpen, child: Text('View all', style: GlType.body(context, size: 11, color: gl.accent))),
            ),
          ),
          Divider(height: 1, color: gl.border),
          for (final (i, r) in _rows.indexed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(r.$1, style: GlType.mono(context, size: 11.5, color: gl.fg1))),
                  Expanded(flex: 2, child: Text(r.$2, style: GlType.mono(context, size: 11.5, color: gl.fg3))),
                  Expanded(child: Text(r.$3, style: GlType.mono(context, size: 11.5, color: gl.fg3))),
                  GlStatusPill(r.$4, color: toneFor(r.$4)),
                ],
              ),
            ),
            if (i < _rows.length - 1) Divider(height: 1, color: gl.border),
          ],
        ],
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.jobs});
  final List<PdfJob> jobs;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final running = jobs.where((j) => j.status is JobRunning).toList();
    return GlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlSectionHeader(
            markerColor: gl.green,
            title: 'Queue',
            trailing: Text('${running.length} running', style: GlType.mono(context, size: 10, color: gl.fg3)),
          ),
          const SizedBox(height: 14),
          if (running.isEmpty)
            _fakeBar(context, 'batch · statements', 0.64)
          else
            for (final j in running.take(3)) _liveBar(context, j),
          if (running.isEmpty) ...[
            const SizedBox(height: 12),
            _fakeBar(context, 'report-monthly', 0.31),
            const SizedBox(height: 12),
            _fakeBar(context, 'certificate-batch', 0.0, pending: true),
          ],
          const SizedBox(height: 16),
          Divider(height: 1, color: gl.border),
          const SizedBox(height: 12),
          Text('RENDERER & ADAPTERS', style: GlType.label(context).copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          _kv(context, 'web-canvas renderer', '✓ active', gl.green),
          _kv(context, 'worker pool', '4 / 4', gl.fg3),
          _kv(context, 'fonts registered', '3', gl.fg3),
        ],
      ),
    );
  }

  Widget _liveBar(BuildContext context, PdfJob j) {
    final p = (j.status as JobRunning).progress;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _bar(context, j.label, p, context.gl.accent),
    );
  }

  Widget _fakeBar(BuildContext context, String label, double p, {bool pending = false}) =>
      _bar(context, label, p, pending ? context.gl.fg4 : context.gl.accent, pending: pending);

  Widget _bar(BuildContext context, String label, double p, Color color, {bool pending = false}) {
    final gl = context.gl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: GlType.body(context, size: 11.5, color: gl.fg2))),
            Text(pending ? 'pending' : '${(p * 100).round()}%', style: GlType.mono(context, size: 10, color: gl.fg3)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: GlRadius.pill,
          child: LinearProgressIndicator(value: pending ? 0 : p, minHeight: 6, backgroundColor: gl.input, color: color),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v, Color vc) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: GlType.body(context, size: 11.5, color: context.gl.fg2)),
            Text(v, style: GlType.mono(context, size: 11, color: vc)),
          ],
        ),
      );
}
