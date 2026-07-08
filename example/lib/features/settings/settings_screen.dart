import 'package:flutter/material.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Settings — the composition root, made visible. Shows the injected adapters
/// (renderer, file / print / share gateways) and generation defaults. In the
/// demo these read the wired defaults; swapping them is a code change at
/// `createStudioClient`, which is the point: the core only sees interfaces.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Extend · Settings'),
        const SizedBox(height: 4),
        Text('Composition root', style: GlType.display(context, size: 24)),
        const SizedBox(height: 4),
        Text('The single place where concrete implementations meet. Domain and application depend only on the interfaces named below.',
            style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 18),
        GlCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _adapter(context, 'Renderer', 'PdfRenderer', 'isolate → web-canvas', gl.green),
            Divider(height: 1, color: gl.border),
            _adapter(context, 'File gateway', 'FileGateway', 'share-pdf', gl.green),
            Divider(height: 1, color: gl.border),
            _adapter(context, 'Print gateway', 'PrintGateway', 'printing', gl.green),
            Divider(height: 1, color: gl.border),
            _adapter(context, 'Share gateway', 'ShareGateway', 'printing share', gl.orange),
          ]),
        ),
        const SizedBox(height: 16),
        _toggleRow(context, 'Generate off the main isolate', 'Use the Dart isolate runner when the document is serializable', true),
        const SizedBox(height: 10),
        _toggleRow(context, 'Retry failed jobs', 'Exponential backoff, capped at 3 attempts for retryable failures', true),
        const SizedBox(height: 10),
        _valueRow(context, 'Worker concurrency', '4'),
        const SizedBox(height: 10),
        _valueRow(context, 'Default page size', 'A4'),
      ],
    );
  }

  Widget _adapter(BuildContext context, String title, String iface, String impl, Color dot) {
    final gl = context.gl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GlType.body(context, size: 12.5, weight: FontWeight.w600, color: gl.fg1)),
            Text(iface, style: GlType.mono(context, size: 11, color: gl.fg4)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: gl.input, borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: gl.border)),
          child: Text(impl, style: GlType.body(context, size: 12, color: gl.fg1)),
        ),
        const SizedBox(width: 12),
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      ]),
    );
  }

  Widget _toggleRow(BuildContext context, String title, String sub, bool on) {
    final gl = context.gl;
    return GlCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GlType.body(context, size: 12.5, weight: FontWeight.w600, color: gl.fg1)),
            const SizedBox(height: 2),
            Text(sub, style: GlType.body(context, size: 11.5, color: gl.fg3)),
          ]),
        ),
        _FakeSwitch(on: on),
      ]),
    );
  }

  Widget _valueRow(BuildContext context, String title, String value) {
    final gl = context.gl;
    return GlCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Expanded(child: Text(title, style: GlType.body(context, size: 12.5, weight: FontWeight.w600, color: gl.fg1))),
        Text(value, style: GlType.mono(context, size: 12.5, color: gl.fg2)),
      ]),
    );
  }
}

class _FakeSwitch extends StatelessWidget {
  const _FakeSwitch({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      width: 38, height: 21,
      decoration: BoxDecoration(color: on ? gl.accent : gl.input, borderRadius: GlRadius.pill, border: Border.all(color: on ? gl.accent : gl.border)),
      child: Align(
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(width: 15, height: 15, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}
