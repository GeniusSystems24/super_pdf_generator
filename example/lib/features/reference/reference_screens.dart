import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

// ============================================================================
// COMPONENT GALLERY
// ============================================================================

class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  static const _catalog = <(String, String, String)>[
    ('pdf.heading', 'TEXT', 'level · align · color'),
    ('pdf.paragraph', 'TEXT', 'leading · align · dir'),
    ('pdf.richText', 'TEXT', 'spans · styles'),
    ('pdf.table', 'DATA', 'columns · rows · zebra'),
    ('pdf.keyValue', 'DATA', 'pairs · columns · dir'),
    ('pdf.list', 'DATA', 'items · ordered'),
    ('pdf.qrCode', 'MEDIA', 'value · ecl · size'),
    ('pdf.image', 'MEDIA', 'assetKey · fit · alt'),
    ('pdf.statusBadge', 'DOC', 'tone · label'),
    ('pdf.keepTogether', 'LAYOUT', 'children'),
    ('pdf.header', 'DOC', 'title · rule'),
    ('pdf.signatureBlock', 'DOC', 'name · role'),
  ];

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Build · Component gallery'),
        const SizedBox(height: 4),
        Text('31 components', style: GlType.display(context, size: 24)),
        const SizedBox(height: 4),
        Text('Every component is a pure, immutable node built by the `pdf.*` factory and rendered by the engine adapter.',
            style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 3 : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _catalog)
                SizedBox(
                  width: (c.maxWidth - (cols - 1) * 12) / cols,
                  child: GlCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(item.$1, style: GlType.mono(context, size: 12.5, color: gl.fg1, weight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: gl.border), borderRadius: GlRadius.pill),
                            child: Text(item.$2, style: TextStyle(fontSize: 8.5, color: gl.fg4, letterSpacing: 0.5)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(item.$3, style: GlType.body(context, size: 11.5, color: gl.fg3)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

// ============================================================================
// RTL & LOCALIZATION  (live)
// ============================================================================

class RtlScreen extends StatelessWidget {
  const RtlScreen({super.key, required this.builder});
  final BuilderController builder;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return AnimatedBuilder(
      animation: builder,
      builder: (context, _) {
        final rtl = builder.direction == PdfDirection.rtl;
        return Row(
          children: [
            Container(
              width: 240,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: gl.border))),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GlEyebrow('Quality · RTL'),
                  const SizedBox(height: 14),
                  GlField(
                    label: 'Direction',
                    child: GlSegmented<PdfDirection>(
                      value: builder.direction,
                      segments: const {PdfDirection.ltr: 'LTR', PdfDirection.rtl: 'RTL'},
                      onChanged: builder.setDirection,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('FONTS', style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9)),
                  const SizedBox(height: 8),
                  _font(context, 'IBM Plex Sans', 'Latin'),
                  _font(context, 'IBM Plex Arabic', 'Arabic'),
                  _font(context, 'Noto fallback', 'bidi'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: gl.orange.withOpacity(0.08), borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: gl.orange.withOpacity(0.24))),
                    child: Text('Numbers, dates & currency reformat per locale via Intl-backed formatters. The whole document mirrors when direction is RTL.',
                        style: GlType.body(context, size: 10.5, color: gl.fg2).copyWith(height: 1.5)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: gl.bg,
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 440,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))]),
                    padding: const EdgeInsets.all(34),
                    child: Directionality(
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(rtl ? 'فاتورة' : 'Invoice', style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w800, fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(rtl ? 'INV-2042 · ٢٠٢٦/٠٢/١٤' : 'INV-2042 · 2026-02-14', style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                          const SizedBox(height: 18),
                          Text(rtl ? 'أُعدّت لصالح شركة نورث ويند التجارية. السداد خلال ٣٠ يومًا من تاريخ الإصدار.' : 'Prepared for Northwind Trading LLC. Payment due within 30 days of issue.',
                              style: const TextStyle(color: Color(0xFF333333), fontSize: 12, height: 1.6)),
                          const SizedBox(height: 16),
                          _row(context, rtl ? 'الوصف' : 'Description', rtl ? 'المبلغ' : 'Amount', header: true),
                          _row(context, rtl ? 'ترخيص نظام التصميم' : 'Design system license', rtl ? '١٬٢٠٠٫٠٠' : '1,200.00'),
                          _row(context, rtl ? 'دعم التكامل' : 'Integration support', rtl ? '١٬٨٠٠٫٠٠' : '1,800.00'),
                          const SizedBox(height: 14),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(rtl ? 'الإجمالي المستحق' : 'Total due', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                            Text(rtl ? '٤٬٤٨٥٫٠٠ ر.س' : 'SAR 4,485.00', style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _font(BuildContext context, String name, String cover) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: GlType.mono(context, size: 11, color: context.gl.fg2)),
          Text('✓ $cover', style: GlType.body(context, size: 10.5, color: context.gl.green)),
        ]),
      );

  Widget _row(BuildContext context, String a, String b, {bool header = false}) => Container(
        color: header ? const Color(0xFF111111) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: EdgeInsets.only(bottom: header ? 0 : 0),
        decoration: header ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(color: header ? Colors.white : const Color(0xFF333333), fontSize: header ? 9 : 10.5, fontWeight: header ? FontWeight.w700 : FontWeight.w400))),
          Text(b, style: TextStyle(color: header ? Colors.white : const Color(0xFF111111), fontSize: header ? 9 : 10.5, fontWeight: header ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

class ErrorHandlingScreen extends StatelessWidget {
  const ErrorHandlingScreen({super.key});

  static const _catalog = <(String, String)>[
    ('ValidationFailure', 'orange'), ('FontFailure', 'red'), ('ImageFailure', 'red'),
    ('RenderingFailure', 'red'), ('FileFailure', 'orange'), ('PrintingFailure', 'orange'),
    ('SharingFailure', 'orange'), ('ProcessingFailure', 'red'), ('UnsupportedFeatureFailure', 'grey'),
    ('PermissionFailure', 'orange'), ('CancelledFailure', 'grey'), ('TimeoutFailure', 'orange'),
    ('UnknownFailure', 'grey'),
  ];

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    Color tone(String t) => switch (t) { 'red' => gl.danger, 'orange' => gl.orange, _ => gl.fg4 };
    return Row(
      children: [
        Container(
          width: 260,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: gl.border))),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 10), child: Text('Failure catalog · 13', style: GlType.body(context, size: 12.5, weight: FontWeight.w700, color: gl.fg1))),
              for (final (i, f) in _catalog.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == 1 ? gl.danger.withOpacity(0.09) : Colors.transparent,
                    borderRadius: const BorderRadius.all(GlRadius.md),
                    border: Border(left: BorderSide(color: i == 1 ? gl.danger : Colors.transparent, width: 2)),
                  ),
                  child: Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: tone(f.$2), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(f.$1, style: GlType.mono(context, size: 11.5, color: i == 1 ? gl.fg1 : gl.fg2)),
                  ]),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [GlSectionMarker(gl.danger), const SizedBox(width: 10), Text('Error Inspector', style: GlType.body(context, size: 14, weight: FontWeight.w700, color: gl.fg1)), const SizedBox(width: 10), Text('FontFailure', style: GlType.mono(context, size: 11, color: gl.danger))]),
              const SizedBox(height: 16),
              GlCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Text('FONT_GLYPH_MISSING', style: GlType.mono(context, size: 12, color: gl.danger, weight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        GlStatusPill('RETRYABLE', color: gl.green),
                        const Spacer(),
                        Text('category: font', style: GlType.mono(context, size: 10.5, color: gl.fg4)),
                      ]),
                    ),
                    Divider(height: 1, color: gl.border),
                    _field(context, 'USER MESSAGE', "We couldn't render some Arabic characters. A required font is missing a glyph."),
                    _field(context, 'DEV CODE', 'PdfFontFailure · FONT_GLYPH_MISSING', mono: true),
                    _field(context, 'CAUSE', 'GlyphNotFoundError: U+2069 in "Amiri"', mono: true),
                    _field(context, 'RECOVERY', 'Register a fallback font covering Arabic presentation forms, then retry generation.'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DISCRIMINATED UNION', style: GlType.label(context).copyWith(fontSize: 9.5)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF0E0F13), borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: gl.border)),
                    child: SelectableText(
                      'switch (failure) {\n'
                      '  case FontFailure(:final code): …\n'
                      '  case ValidationFailure(): …\n'
                      '  // exhaustive — the compiler enforces every branch\n'
                      '}',
                      style: GlType.mono(context, size: 12, color: const Color(0xFFC3C6D7)).copyWith(height: 1.6),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, String label, String value, {bool mono = false}) {
    final gl = context.gl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9))),
        const SizedBox(width: 14),
        Expanded(child: Text(value, style: mono ? GlType.mono(context, size: 11, color: gl.fg2) : GlType.body(context, size: 12, color: gl.fg1).copyWith(height: 1.4))),
      ]),
    );
  }
}

// ============================================================================
// PERFORMANCE
// ============================================================================

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Quality · Performance'),
        const SizedBox(height: 4),
        Text('Performance dashboard', style: GlType.display(context, size: 24)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: GlStatCard(label: '500-page generate', value: '3.8s', sub: 'isolate · non-blocking', subColor: gl.green)),
          const SizedBox(width: 12),
          Expanded(child: GlStatCard(label: 'Peak memory', value: '218MB', sub: 'released after flush')),
          const SizedBox(width: 12),
          Expanded(child: GlStatCard(label: 'Font cache hits', value: '96%', sub: '3 fonts cached', subColor: gl.green)),
          const SizedBox(width: 12),
          Expanded(child: GlStatCard(label: 'Blob URLs live', value: '0', sub: 'all revoked ✓', subColor: gl.green)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: GlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GlSectionHeader(markerColor: gl.accent, title: 'Generation time vs. page count'),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final e in const [('10', 0.14), ('100', 0.32), ('500', 0.58), ('1k', 0.82), ('2k', 1.0)])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Container(height: 130 * e.$2, decoration: BoxDecoration(color: gl.accent, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                              const SizedBox(height: 6),
                              Text(e.$1, style: GlType.mono(context, size: 9, color: gl.fg4)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: GlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GlSectionHeader(markerColor: gl.green, title: 'Worker pool'),
                const SizedBox(height: 16),
                _worker(context, 'worker-0', 0.88, 'busy · gen', gl.accent),
                _worker(context, 'worker-1', 0.74, 'busy · gen', gl.accent),
                _worker(context, 'worker-2', 0.06, 'idle', gl.green),
                _worker(context, 'worker-3', 0.06, 'idle', gl.green),
                const SizedBox(height: 8),
                Divider(height: 1, color: gl.border),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Fallback', style: GlType.body(context, size: 11.5, color: gl.fg3)),
                  Text('main-thread ready', style: GlType.mono(context, size: 11, color: gl.fg2)),
                ]),
              ]),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _worker(BuildContext context, String name, double load, String state, Color color) {
    final gl = context.gl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(name, style: GlType.mono(context, size: 11, color: gl.fg2)),
          Text(state, style: GlType.body(context, size: 10.5, color: color)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: GlRadius.pill, child: LinearProgressIndicator(value: load, minHeight: 5, backgroundColor: gl.input, color: color)),
      ]),
    );
  }
}

// ============================================================================
// TEMPLATES  (optional pack)
// ============================================================================

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key, required this.builder, required this.onOpen});
  final BuilderController builder;
  final VoidCallback onOpen;

  void _use(List<PdfComponent> blocks, String title) {
    builder.clear();
    builder.setMetadata(title: title);
    for (final b in blocks) {
      builder.add(b);
    }
    onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final templates = <(String, String, List<PdfComponent>)>[
      ('Invoice', 'bilingual · VAT · totals', [
        pdf.heading('Invoice'),
        pdf.keyValue(const [MapEntry('Invoice No', 'INV-2042'), MapEntry('Date', '2026-02-14')]),
        pdf.table(columns: const ['Description', 'Amount'], rows: const [['License', '1,200'], ['Support', '1,800']]),
        pdf.statusBadge(label: 'AWAITING PAYMENT', tone: 'orange'),
      ]),
      ('Financial report', 'sections · charts · KPIs', [
        pdf.heading('Quarterly Report'),
        pdf.paragraph('Summary of Q4 2026 performance.'),
        pdf.keyValue(const [MapEntry('Revenue', '4.2M'), MapEntry('Growth', '+12%')]),
      ]),
      ('Certificate', 'seal · signature block', [
        pdf.heading('Certificate of Completion'),
        pdf.paragraph('This certifies the successful completion of the program.'),
        pdf.signatureBlock(name: 'A. Director', role: 'Program Lead'),
      ]),
      ('Receipt', 'compact · thermal-ready', [
        pdf.heading('Receipt', level: 2),
        pdf.keyValue(const [MapEntry('Item', 'Subscription'), MapEntry('Total', 'SAR 99.00')]),
      ]),
      ('Statement', 'transactions · running balance', [
        pdf.heading('Account Statement'),
        pdf.table(columns: const ['Date', 'Description', 'Amount'], rows: const [['11-01', 'Charge', '120'], ['11-08', 'Payment', '-90']]),
      ]),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: gl.orange.withOpacity(0.08), borderRadius: const BorderRadius.all(GlRadius.lg), border: Border.all(color: gl.orange.withOpacity(0.26))),
          child: Row(children: [
            GlSectionMarker(gl.orange, height: 32),
            const SizedBox(width: 12),
            Expanded(child: Text('Deliberately last in the nav. @folio/pdf-templates is an optional pack — each template is a function returning a PdfDocumentDefinition built from the same pdf.* components. The core has zero knowledge of it.', style: GlType.body(context, size: 12.5, color: gl.fg2).copyWith(height: 1.5))),
          ]),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 3 : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in templates)
                SizedBox(
                  width: (c.maxWidth - (cols - 1) * 12) / cols,
                  child: GlCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 96,
                          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: GlRadius.lg)),
                          padding: const EdgeInsets.all(14),
                          child: Text(t.$1, style: const TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('templates.${t.$1.toLowerCase().split(' ').first}', style: GlType.mono(context, size: 11.5, color: gl.fg1)),
                            const SizedBox(height: 3),
                            Text(t.$2, style: GlType.body(context, size: 10.5, color: gl.fg3)),
                            const SizedBox(height: 10),
                            GlGhostButton(label: 'Use in builder', icon: Icons.open_in_new_rounded, onPressed: () => _use(t.$3, t.$1)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

// ============================================================================
// API REFERENCE
// ============================================================================

class ApiReferenceScreen extends StatelessWidget {
  const ApiReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Row(
      children: [
        Container(
          width: 210,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: gl.border))),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _group(context, 'CLIENT', ['createPdfClient', 'client.generate', 'client.process', 'client.enqueue'], 0),
              _group(context, 'BUILDER', ['pdfDocument', 'pdf.heading', 'pdf.table'], -1),
              _group(context, 'JOBS', ['jobs.enqueue', 'jobs.watch', 'jobs.retry'], -1),
              _group(context, 'CONTRACTS', ['PdfRenderer', 'FileGateway', 'PrintGateway'], -1),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(children: [
                Text('createPdfClient', style: GlType.mono(context, size: 16, color: gl.fg1, weight: FontWeight.w700)),
                const SizedBox(width: 10),
                GlStatusPill('FACTORY', color: gl.accent),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: gl.input, borderRadius: GlRadius.pill), child: Text('super_pdf_generator', style: GlType.mono(context, size: 9.5, color: gl.fg3))),
              ]),
              const SizedBox(height: 8),
              Text('Creates a high-level client from injected adapters. The single composition seam for the whole SDK.', style: GlType.body(context, size: 12.5, color: gl.fg3)),
              const SizedBox(height: 16),
              Text('SIGNATURE', style: GlType.label(context).copyWith(fontSize: 9.5)),
              const SizedBox(height: 8),
              _code(context,
                  'PdfClient createPdfClient({\n'
                  '  required PdfRenderer renderer,\n'
                  '  FileGateway? fileGateway,\n'
                  '  PrintGateway? printGateway,\n'
                  '  ShareGateway? shareGateway,\n'
                  '  PdfLogger logger,\n'
                  '  int concurrency,\n'
                  '});'),
              const SizedBox(height: 16),
              Text('EXAMPLE', style: GlType.label(context).copyWith(fontSize: 9.5)),
              const SizedBox(height: 8),
              _code(context,
                  "final client = createStudioClient();\n\n"
                  "final doc = pdfDocument()\n"
                  "  .metadata(title: 'Invoice')\n"
                  "  .content([pdf.heading('Invoice'), pdf.table(...)])\n"
                  "  .build();\n\n"
                  "final result = await client.generate(\n"
                  "  PdfGenerationRequest(fileName: 'invoice.pdf', document: doc),\n"
                  ");"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, String title, List<String> items, int active) {
    final gl = context.gl;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 5), child: Text(title, style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9))),
      for (final (i, it) in items.indexed)
        Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: i == active ? gl.accent.withOpacity(0.1) : Colors.transparent,
            borderRadius: const BorderRadius.all(GlRadius.sm),
            border: Border(left: BorderSide(color: i == active ? gl.accent : Colors.transparent, width: 2)),
          ),
          child: Text(it, style: GlType.mono(context, size: 11, color: i == active ? gl.accent : gl.fg2)),
        ),
    ]);
  }

  Widget _code(BuildContext context, String code) {
    final gl = context.gl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0E0F13), borderRadius: const BorderRadius.all(GlRadius.lg), border: Border.all(color: gl.border)),
      child: SelectableText(code, style: GlType.mono(context, size: 12, color: const Color(0xFFC3C6D7)).copyWith(height: 1.7)),
    );
  }
}
