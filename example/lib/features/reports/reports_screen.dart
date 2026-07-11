import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Metadata for one entry in the report library rail.
class _ReportEntry {
  const _ReportEntry(this.kind, this.blurb, this.icon, this.color, this.pages);
  final ReportKind kind;
  final String blurb;
  final IconData icon;
  final Color color;
  final String pages;
}

/// Reports — the reference screen for the faithful GeniusLink report module.
///
/// Loads [GeniusReports] once (decoding the bundled Arabic + Latin fonts), lets
/// the user pick a document type and reading direction, then generates the PDF
/// from [ReportSamples] and shows it live in the `printing` preview (print /
/// share / save come from the viewer toolbar).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  GeniusReports? _reports;
  Object? _error;

  ReportKind _kind = ReportKind.taxInvoice;
  ReportDir _dir = ReportDir.ltr;

  static const _entries = <_ReportEntry>[
    _ReportEntry(ReportKind.taxInvoice,
        'VAT invoice — bilingual header, line items, totals & signature',
        Icons.receipt_long_outlined, Color(0xFF4A7CFF), '1 page'),
    _ReportEntry(ReportKind.trialBalance,
        'Grouped account balances, subtotals, dark grand-total band',
        Icons.account_balance_outlined, Color(0xFF1DB88A), '2 pages'),
    _ReportEntry(ReportKind.customerStatement,
        'Transaction ledger with running balance & aging analysis',
        Icons.description_outlined, Color(0xFF4A7CFF), '1 page'),
    _ReportEntry(ReportKind.inventoryValuation,
        'Stock valuation grouped by category, running footer',
        Icons.inventory_2_outlined, Color(0xFFF97316), '2 pages'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await GeniusReports.load();
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<Uint8List> _generate() {
    final r = _reports!;
    switch (_kind) {
      case ReportKind.taxInvoice:
        return r.taxInvoice(ReportSamples.taxInvoice(), dir: _dir);
      case ReportKind.trialBalance:
        return r.trialBalance(ReportSamples.trialBalance(), dir: _dir);
      case ReportKind.customerStatement:
        return r.customerStatement(ReportSamples.customerStatement(), dir: _dir);
      case ReportKind.inventoryValuation:
        return r.inventoryValuation(ReportSamples.inventory(), dir: _dir);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    if (_error != null) {
      return Center(
        child: GlCard(
          child: Text('Could not load report fonts:\n$_error',
              style: GlType.body(context, color: gl.danger)),
        ),
      );
    }
    if (_reports == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: gl.accent, strokeWidth: 2),
          const SizedBox(height: 14),
          Text('Loading Arabic + Latin fonts…', style: GlType.body(context, color: gl.fg3)),
        ]),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: _rail(context)),
        Container(width: 1, color: gl.border),
        Expanded(child: _preview(context)),
      ],
    );
  }

  Widget _rail(BuildContext context) {
    final gl = context.gl;
    return Container(
      color: gl.bg,
      child: ListView(
        padding: const EdgeInsets.all(GlSpace.s5),
        children: [
          Row(
            children: [
              GlSectionMarker(gl.accent, height: 34),
              const SizedBox(width: GlSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Library',
                        style: GlType.body(context, size: 16, weight: FontWeight.w700, color: gl.fg1)),
                    const SizedBox(height: 2),
                    Text('Pixel-faithful GeniusLink documents',
                        style: GlType.body(context, size: 12, color: gl.fg3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: GlSpace.s5),
          Text('READING DIRECTION', style: GlType.label(context).copyWith(fontSize: 9.5)),
          const SizedBox(height: GlSpace.s2),
          GlSegmented<ReportDir>(
            value: _dir,
            segments: const {ReportDir.ltr: 'LTR · English', ReportDir.rtl: 'RTL · العربية'},
            onChanged: (d) => setState(() => _dir = d),
          ),
          const SizedBox(height: GlSpace.s5),
          Text('DOCUMENTS', style: GlType.label(context).copyWith(fontSize: 9.5)),
          const SizedBox(height: GlSpace.s2),
          for (final e in _entries) ...[
            _DocCard(
              entry: e,
              label: _dir.isRtl ? e.kind.labelAr : e.kind.label,
              selected: e.kind == _kind,
              onTap: () => setState(() => _kind = e.kind),
            ),
            const SizedBox(height: GlSpace.s3),
          ],
          const SizedBox(height: GlSpace.s3),
          _snippet(context),
        ],
      ),
    );
  }

  Widget _snippet(BuildContext context) {
    final gl = context.gl;
    final method = switch (_kind) {
      ReportKind.taxInvoice => 'taxInvoice',
      ReportKind.trialBalance => 'trialBalance',
      ReportKind.customerStatement => 'customerStatement',
      ReportKind.inventoryValuation => 'inventoryValuation',
    };
    final sample = switch (_kind) {
      ReportKind.taxInvoice => 'ReportSamples.taxInvoice()',
      ReportKind.trialBalance => 'ReportSamples.trialBalance()',
      ReportKind.customerStatement => 'ReportSamples.customerStatement()',
      ReportKind.inventoryValuation => 'ReportSamples.inventory()',
    };
    final code = 'final reports = await GeniusReports.load();\n'
        'final bytes = await reports.$method(\n'
        '  $sample,\n'
        '  dir: ReportDir.${_dir.name},\n'
        ');';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GlSpace.s4),
      decoration: BoxDecoration(
        color: gl.surface2,
        borderRadius: GlRadius.card,
        border: Border.all(color: gl.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.code_rounded, size: 14, color: gl.fg3),
            const SizedBox(width: 6),
            Text('USAGE', style: GlType.label(context).copyWith(fontSize: 9.5)),
          ]),
          const SizedBox(height: GlSpace.s3),
          Text(code, style: GlType.mono(context, size: 11, color: gl.fg2)),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final gl = context.gl;
    final label = _dir.isRtl ? _kind.labelAr : _kind.label;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
          child: Row(
            children: [
              GlSectionMarker(gl.accent),
              const SizedBox(width: 10),
              Text(label, style: GlType.body(context, size: 14, weight: FontWeight.w700, color: gl.fg1)),
              const SizedBox(width: 8),
              GlStatusPill(_dir.isRtl ? 'RTL' : 'LTR', color: gl.accent),
              const Spacer(),
              Text('Generated from ReportSamples · print & share in toolbar',
                  style: GlType.body(context, size: 11.5, color: gl.fg3)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: gl.bg,
            child: PdfPreview(
              key: ValueKey('${_kind.name}-${_dir.name}'),
              build: (_) => _generate(),
              useActions: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              loadingWidget: Center(child: CircularProgressIndicator(color: gl.accent)),
              pdfPreviewPageDecoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
              previewPageMargin: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.entry, required this.label, required this.selected, required this.onTap});
  final _ReportEntry entry;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: GlRadius.card,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(GlSpace.s4),
          decoration: BoxDecoration(
            color: selected ? gl.hover : gl.surface,
            borderRadius: GlRadius.card,
            border: Border.all(color: selected ? entry.color : gl.border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.14),
                  borderRadius: const BorderRadius.all(GlRadius.md),
                ),
                child: Icon(entry.icon, size: 18, color: entry.color),
              ),
              const SizedBox(width: GlSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: GlType.body(context, size: 13.5, weight: FontWeight.w700, color: gl.fg1)),
                        ),
                        Text(entry.pages, style: GlType.mono(context, size: 10, color: gl.fg3)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(entry.blurb, style: GlType.body(context, size: 11.5, color: gl.fg3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
