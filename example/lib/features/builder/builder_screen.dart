import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// Document Builder — three panes (palette · canvas · inspector) over the
/// [BuilderController] presentation model. Every control maps to a `pdf.*`
/// call; a Visual/Source toggle round-trips to generated Dart, so the builder
/// visualises the API rather than replacing it.
class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key, required this.controller, required this.onPreview});
  final BuilderController controller;
  final VoidCallback onPreview;

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  bool _source = false;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Row(
          children: [
            SizedBox(width: 186, child: _Palette(controller: widget.controller)),
            Container(width: 1, color: gl.border),
            Expanded(
              child: Column(
                children: [
                  _CanvasToolbar(
                    source: _source,
                    controller: widget.controller,
                    onToggle: (v) => setState(() => _source = v),
                    onPreview: widget.onPreview,
                  ),
                  Expanded(child: _source ? _SourceView(controller: widget.controller) : _Canvas(controller: widget.controller)),
                ],
              ),
            ),
            Container(width: 1, color: gl.border),
            SizedBox(width: 236, child: _Inspector(controller: widget.controller)),
          ],
        );
      },
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.controller});
  final BuilderController controller;

  static const _groups = <String, List<(String, String)>>{
    'TEXT': [('Heading', 'heading'), ('Paragraph', 'paragraph')],
    'LAYOUT': [('Divider', 'divider'), ('Spacer', 'spacer')],
    'DATA': [('Table', 'table'), ('Key-value', 'keyValue'), ('List', 'list')],
    'MEDIA & DOC': [('Image', 'image'), ('QR code', 'qr'), ('Status badge', 'statusBadge')],
  };

  PdfComponent _make(String kind) => switch (kind) {
        'heading' => pdf.heading('New heading'),
        'paragraph' => pdf.paragraph('New paragraph of body text.'),
        'divider' => pdf.divider(),
        'spacer' => pdf.spacer(12),
        'table' => pdf.table(columns: const ['Column A', 'Column B'], rows: const [
            ['Row 1', 'Value'],
            ['Row 2', 'Value'],
          ]),
        'keyValue' => pdf.keyValue(const [MapEntry('Key', 'Value'), MapEntry('Total', '0.00')]),
        'list' => pdf.bulletList(const ['First item', 'Second item']),
        'image' => pdf.image(label: 'Image placeholder'),
        'qr' => pdf.qrCode('https://folio.dev'),
        'statusBadge' => pdf.statusBadge(label: 'PAID', tone: 'green'),
        _ => pdf.paragraph('Text'),
      };

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          child: Text('Components', style: GlType.body(context, size: 12.5, weight: FontWeight.w700, color: gl.fg1)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in _Palette._groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 7),
                  child: Text(entry.key, style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9)),
                ),
                for (final item in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: _PaletteChip(label: item.$1, onTap: () => controller.add(_make(item.$2))),
                  ),
                const SizedBox(height: 6),
              ],
              Divider(height: 20, color: gl.border),
              GlGhostButton(label: 'Load sample invoice', icon: Icons.auto_awesome_outlined, onPressed: controller.seedSample),
              const SizedBox(height: 7),
              GlGhostButton(label: 'Clear document', icon: Icons.delete_outline_rounded, danger: true, onPressed: controller.clear),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Material(
      color: gl.surface,
      borderRadius: const BorderRadius.all(GlRadius.md),
      child: InkWell(
        borderRadius: const BorderRadius.all(GlRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: gl.border), borderRadius: const BorderRadius.all(GlRadius.md)),
          child: Row(
            children: [
              Expanded(child: Text(label, style: GlType.body(context, size: 12, color: gl.fg2))),
              Icon(Icons.add_rounded, size: 14, color: gl.fg4),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({required this.source, required this.controller, required this.onToggle, required this.onPreview});
  final bool source;
  final BuilderController controller;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
      child: Row(
        children: [
          GlSegmented<bool>(value: source, segments: const {false: 'Visual', true: 'Source'}, onChanged: onToggle),
          const Spacer(),
          Text('${controller.blocks.length} blocks', style: GlType.mono(context, size: 11, color: gl.fg3)),
          const SizedBox(width: 14),
          GlGhostButton(label: 'Preview', icon: Icons.visibility_outlined, onPressed: onPreview),
          const SizedBox(width: 8),
          GlPrimaryButton(
            label: 'Generate PDF',
            icon: Icons.bolt_rounded,
            busy: controller.generation is PdfGenGenerating || controller.generation is PdfGenPreparing,
            onPressed: controller.generate,
          ),
        ],
      ),
    );
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({required this.controller});
  final BuilderController controller;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Container(
      color: gl.bg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Container(
            width: 460,
            constraints: const BoxConstraints(minHeight: 560),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 14))],
            ),
            padding: const EdgeInsets.all(34),
            child: Directionality(
              textDirection: controller.direction == PdfDirection.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final block in controller.blocks)
                    _CanvasBlock(
                      selected: block.id == controller.selectedId,
                      accent: Color(controller.accent.argb),
                      component: block.component,
                      onTap: () => controller.select(block.id),
                    ),
                  if (controller.blocks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      child: Text('Empty document — add a component from the palette.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasBlock extends StatelessWidget {
  const _CanvasBlock({required this.selected, required this.component, required this.onTap, required this.accent});
  final bool selected;
  final PdfComponent component;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _render(context, component, accent),
      ),
    );
  }

  Widget _render(BuildContext context, PdfComponent c, Color accent) {
    switch (c) {
      case PdfHeading(:final text, :final level):
        return Text(text, style: TextStyle(color: const Color(0xFF111111), fontWeight: FontWeight.w800, fontSize: level == 1 ? 20 : (level == 3 ? 13 : 16)));
      case PdfParagraph(:final text):
        return Text(text, style: const TextStyle(color: Color(0xFF333333), fontSize: 12, height: 1.5));
      case PdfText(:final text):
        return Text(text, style: const TextStyle(color: Color(0xFF333333), fontSize: 12));
      case PdfDivider():
        return const Divider(height: 12, color: Color(0xFFE5E5E5));
      case PdfSpacer(:final size):
        return SizedBox(height: size);
      case PdfKeyValueSection(:final pairs):
        return Column(
          children: [
            for (final p in pairs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(p.key, style: const TextStyle(color: Color(0xFF888888), fontSize: 10.5)),
                  Text(p.value, style: const TextStyle(color: Color(0xFF111111), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        );
      case PdfList(:final items, :final ordered):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, it) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text('${ordered ? '${i + 1}.' : '•'}  $it', style: const TextStyle(color: Color(0xFF333333), fontSize: 11)),
              ),
          ],
        );
      case PdfTable(:final columns, :final rows):
        return Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE))),
          child: Column(
            children: [
              Container(
                color: const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [for (final col in columns) Expanded(child: Text(col, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))]),
              ),
              for (final (i, row) in rows.indexed)
                Container(
                  color: i.isOdd ? const Color(0xFFFAFAFA) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(children: [for (final cell in row) Expanded(child: Text(cell, style: const TextStyle(color: Color(0xFF333333), fontSize: 10)))]),
                ),
            ],
          ),
        );
      case PdfStatusBadge(:final label, :final tone):
        final c = switch (tone) { 'green' => const Color(0xFF127A3E), 'orange' => const Color(0xFFB25000), 'red' => const Color(0xFFC0392B), _ => accent };
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        );
      case PdfQrCode(:final value):
        return Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF111111))), child: const Icon(Icons.qr_code_2, color: Color(0xFF111111), size: 40)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF888888), fontSize: 9))),
        ]);
      case PdfImage(:final label):
        return Container(height: 74, alignment: Alignment.center, color: const Color(0xFFF4F4F4), child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)));
      default:
        return Text(c.runtimeType.toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 10));
    }
  }
}

class _SourceView extends StatelessWidget {
  const _SourceView({required this.controller});
  final BuilderController controller;

  String _line(PdfComponent c) {
    switch (c) {
      case PdfHeading(:final text, :final level):
        return "  pdf.heading('$text'${level == 1 ? '' : ', level: $level'}),";
      case PdfParagraph(:final text):
        return "  pdf.paragraph('$text'),";
      case PdfDivider():
        return '  pdf.divider(),';
      case PdfSpacer(:final size):
        return '  pdf.spacer(${size.toStringAsFixed(0)}),';
      case PdfKeyValueSection(:final pairs):
        final entries = pairs.map((p) => "MapEntry('${p.key}', '${p.value}')").join(', ');
        return '  pdf.keyValue(const [$entries]),';
      case PdfList(:final items, :final ordered):
        final list = items.map((e) => "'$e'").join(', ');
        return "  pdf.${ordered ? 'numberedList' : 'bulletList'}(const [$list]),";
      case PdfTable(:final columns, :final rows):
        final cols = columns.map((e) => "'$e'").join(', ');
        return "  pdf.table(columns: const [$cols], rows: const [ ${rows.map((r) => '[${r.map((e) => "'$e'").join(', ')}]').join(', ')} ]),";
      case PdfStatusBadge(:final label, :final tone):
        return "  pdf.statusBadge(label: '$label', tone: '$tone'),";
      case PdfQrCode(:final value):
        return "  pdf.qrCode('$value'),";
      case PdfImage(:final label):
        return "  pdf.image(label: '$label'),";
      default:
        return '  // ${c.runtimeType}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final m = controller.metadata;
    final buffer = StringBuffer()
      ..writeln('final document = pdfDocument()')
      ..writeln("  .metadata(title: '${m.title}', author: '${m.author}')")
      ..writeln('  .page(size: PdfPageSize.${controller.size.name.toLowerCase()}, marginsAll: ${controller.margins.top.toStringAsFixed(0)})')
      ..writeln('  .content([');
    for (final b in controller.blocks) {
      buffer.writeln('  ${_line(b.component)}');
    }
    buffer
      ..writeln('  ])')
      ..writeln('  .build();');
    return Container(
      color: const Color(0xFF0E0F13),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(buffer.toString(), style: GlType.mono(context, size: 12.5, color: const Color(0xFFC3C6D7)).copyWith(height: 1.7)),
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.controller});
  final BuilderController controller;

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final block = controller.selected;
    if (block == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Select a block to edit its properties.', textAlign: TextAlign.center, style: GlType.body(context, size: 12, color: gl.fg3))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
          child: Row(children: [
            GlSectionMarker(gl.accent),
            const SizedBox(width: 10),
            Text(_title(block.component), style: GlType.body(context, size: 13, weight: FontWeight.w700, color: gl.fg1)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(15), children: _fields(context, block))),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: gl.border))),
          child: Row(children: [
            Expanded(child: GlGhostButton(label: 'Duplicate', icon: Icons.copy_rounded, onPressed: () => controller.duplicate(block.id))),
            const SizedBox(width: 8),
            Expanded(child: GlGhostButton(label: 'Delete', icon: Icons.delete_outline_rounded, danger: true, onPressed: () => controller.remove(block.id))),
          ]),
        ),
      ],
    );
  }

  String _title(PdfComponent c) => switch (c) {
        PdfHeading() => 'Heading', PdfParagraph() => 'Paragraph', PdfTable() => 'Table',
        PdfKeyValueSection() => 'Key-value', PdfList() => 'List', PdfStatusBadge() => 'Status badge',
        PdfQrCode() => 'QR code', PdfImage() => 'Image', PdfDivider() => 'Divider', PdfSpacer() => 'Spacer',
        _ => c.runtimeType.toString(),
      };

  List<Widget> _fields(BuildContext context, BuilderBlock block) {
    final c = block.component;
    final gl = context.gl;
    void set(PdfComponent next) => controller.replace(block.id, next);

    Widget textField(String key, String label, String value, ValueChanged<String> onChanged, {int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlField(
            label: label,
            child: TextFormField(
              key: ValueKey('${block.id}-$key'),
              initialValue: value,
              maxLines: lines,
              onChanged: onChanged,
              style: GlType.body(context, size: 12.5, color: gl.fg1),
              decoration: _dec(context),
            ),
          ),
        );

    switch (c) {
      case PdfHeading(:final text, :final level):
        return [
          textField('t', 'Text', text, (v) => set(pdf.heading(v, level: level))),
          GlField(label: 'Level', child: GlSegmented<int>(value: level, segments: const {1: 'H1', 2: 'H2', 3: 'H3'}, onChanged: (v) => set(pdf.heading(text, level: v)))),
        ];
      case PdfParagraph(:final text, :final align):
        return [
          textField('t', 'Text', text, (v) => set(pdf.paragraph(v, align: align)), lines: 5),
          GlField(label: 'Align', child: GlSegmented<PdfAlign>(value: align, segments: const {PdfAlign.start: 'Start', PdfAlign.center: 'Center', PdfAlign.end: 'End'}, onChanged: (v) => set(pdf.paragraph(text, align: v)))),
        ];
      case PdfStatusBadge(:final label, :final tone):
        return [
          textField('l', 'Label', label, (v) => set(pdf.statusBadge(label: v, tone: tone))),
          GlField(label: 'Tone', child: GlSegmented<String>(value: tone, segments: const {'green': 'Green', 'orange': 'Orange', 'red': 'Red', 'blue': 'Blue'}, onChanged: (v) => set(pdf.statusBadge(label: label, tone: v)))),
        ];
      case PdfQrCode(:final value):
        return [textField('v', 'Value', value, (v) => set(pdf.qrCode(v)))];
      case PdfImage(:final label):
        return [textField('l', 'Label', label, (v) => set(pdf.image(label: v)))];
      case PdfList(:final items, :final ordered):
        return [
          GlField(label: 'Ordered', child: GlSegmented<bool>(value: ordered, segments: const {false: 'Bullet', true: 'Numbered'}, onChanged: (v) => set(pdf.list(items, ordered: v)))),
          const SizedBox(height: 14),
          textField('i', 'Items (one per line)', items.join('\n'), (v) => set(pdf.list(v.split('\n').where((e) => e.trim().isNotEmpty).toList(), ordered: ordered)), lines: 6),
        ];
      case PdfKeyValueSection(:final pairs):
        return [
          textField('kv', 'Pairs (key = value per line)', pairs.map((p) => '${p.key} = ${p.value}').join('\n'), (v) {
            final parsed = <MapEntry<String, String>>[];
            for (final line in v.split('\n')) {
              final i = line.indexOf('=');
              if (i > 0) parsed.add(MapEntry(line.substring(0, i).trim(), line.substring(i + 1).trim()));
            }
            set(pdf.keyValue(parsed));
          }, lines: 6),
        ];
      case PdfTable(:final columns, :final rows, :final zebra):
        return [
          textField('c', 'Columns (comma separated)', columns.join(', '), (v) => set(pdf.table(columns: v.split(',').map((e) => e.trim()).toList(), rows: rows, zebra: zebra)), lines: 2),
          textField('r', 'Rows (comma per cell, line per row)', rows.map((r) => r.join(', ')).join('\n'), (v) {
            final parsed = v.split('\n').where((l) => l.trim().isNotEmpty).map((l) => l.split(',').map((e) => e.trim()).toList()).toList();
            set(pdf.table(columns: columns, rows: parsed, zebra: zebra));
          }, lines: 6),
          GlField(label: 'Zebra rows', child: GlSegmented<bool>(value: zebra, segments: const {true: 'On', false: 'Off'}, onChanged: (v) => set(pdf.table(columns: columns, rows: rows, zebra: v)))),
        ];
      default:
        return [Text('This component has no editable properties.', style: GlType.body(context, size: 12, color: gl.fg3))];
    }
  }

  InputDecoration _dec(BuildContext context) {
    final gl = context.gl;
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      filled: true,
      fillColor: gl.input,
      enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(GlRadius.md), borderSide: BorderSide(color: gl.border)),
      focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(GlRadius.md), borderSide: BorderSide(color: gl.accent)),
    );
  }
}
