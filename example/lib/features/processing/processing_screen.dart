import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

enum _Op { merge, split, extract, rotate, watermark }

/// PDF Processing — merge / split / extract / rotate / watermark. Uses the
/// builder's current document (rendered to real bytes) as the input, so every
/// operation runs end-to-end through `client.process` and produces a real
/// output PDF shown in the preview.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.client, required this.builder});
  final PdfClient client;
  final BuilderController builder;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  _Op _op = _Op.watermark;
  bool _busy = false;
  String? _error;
  Uint8List? _output;
  int _outPages = 0;

  double _opacity = 0.14;
  int _turns = 1;
  String _watermark = 'CONFIDENTIAL';
  String _ranges = '1';
  String _extract = '1';

  Future<PdfInputFile> _input() async {
    final req = PdfGenerationRequest(
      fileName: widget.builder.fileName,
      document: widget.builder.document,
      processing: widget.builder.processing,
    );
    final bytes = (await widget.client.toBytes(req)).fold((b) => b, (_) => Uint8List(0));
    return PdfInputFile(name: widget.builder.fileName, bytes: bytes);
  }

  List<PdfPageRange> _parseRanges(String s) {
    final out = <PdfPageRange>[];
    for (final part in s.split(',')) {
      final t = part.trim();
      if (t.isEmpty) continue;
      if (t.contains('-')) {
        final ab = t.split('-');
        final a = int.tryParse(ab[0].trim()), b = int.tryParse(ab.last.trim());
        if (a != null && b != null) out.add(PdfPageRange(a, b));
      } else {
        final n = int.tryParse(t);
        if (n != null) out.add(PdfPageRange(n, n));
      }
    }
    return out.isEmpty ? const [PdfPageRange(1, 1)] : out;
  }

  List<int> _parsePages(String s) =>
      s.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();

  Future<void> _run() async {
    setState(() { _busy = true; _error = null; });
    final input = await _input();
    final PdfProcessingRequest request = switch (_op) {
      _Op.merge => PdfMergeRequest(inputs: [input, input], fileName: 'merged.pdf'),
      _Op.split => PdfSplitRequest(input: input, ranges: _parseRanges(_ranges)),
      _Op.extract => PdfExtractPagesRequest(input: input, pages: _parsePages(_extract)),
      _Op.rotate => PdfRotatePagesRequest(input: input, pages: const [], quarterTurns: _turns),
      _Op.watermark => PdfWatermarkRequest(input: input, text: _watermark, opacity: _opacity),
    };
    final result = await widget.client.process(request);
    if (!mounted) return;
    result.fold(
      (value) => setState(() {
        _output = value.primary.bytes;
        _outPages = value.primary.pageCount;
        _busy = false;
      }),
      (failure) => setState(() { _error = failure.message; _busy = false; }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Row(
      children: [
        // operation rail
        Container(
          width: 168,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: gl.border))),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('OPERATION', style: GlType.label(context, color: gl.fg4).copyWith(fontSize: 9)),
              const SizedBox(height: 8),
              for (final op in _Op.values)
                _OpItem(
                  label: switch (op) { _Op.merge => 'Merge', _Op.split => 'Split', _Op.extract => 'Extract pages', _Op.rotate => 'Rotate', _Op.watermark => 'Watermark' },
                  selected: op == _op,
                  onTap: () => setState(() { _op = op; _output = null; _error = null; }),
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: gl.green.withOpacity(0.08), borderRadius: const BorderRadius.all(GlRadius.md), border: Border.all(color: gl.green.withOpacity(0.24))),
                child: Text('Each op is a serializable ProcessingRequest resolved by client.process().', style: GlType.body(context, size: 10.5, color: gl.fg2)),
              ),
            ],
          ),
        ),
        // config
        Container(
          width: 300,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: gl.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: GlSectionHeader(markerColor: gl.green, title: _opTitle, subtitle: 'Input: ${widget.builder.fileName}'),
              ),
              Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 8), children: _config(context))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlPrimaryButton(label: 'Run ${_opTitle.toLowerCase()}', icon: Icons.play_arrow_rounded, busy: _busy, onPressed: _run),
              ),
            ],
          ),
        ),
        // result
        Expanded(
          child: Container(
            color: gl.bg,
            child: _error != null
                ? _ErrorState(message: _error!)
                : _output == null
                    ? _EmptyState()
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                            child: Row(children: [
                              GlStatusPill('RESULT', color: gl.green),
                              const SizedBox(width: 10),
                              Text('$_outPages pages · ${(_output!.length / 1024).toStringAsFixed(1)} KB', style: GlType.mono(context, size: 11, color: gl.fg3)),
                            ]),
                          ),
                          Expanded(
                            child: PdfPreview(
                              key: ValueKey(_output!.length),
                              build: (_) => _output!,
                              useActions: true,
                              canChangePageFormat: false,
                              canChangeOrientation: false,
                              canDebug: false,
                              previewPageMargin: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  String get _opTitle => switch (_op) {
        _Op.merge => 'Merge PDFs', _Op.split => 'Split PDF', _Op.extract => 'Extract pages', _Op.rotate => 'Rotate pages', _Op.watermark => 'Watermark',
      };

  List<Widget> _config(BuildContext context) {
    final gl = context.gl;
    Widget field(String label, String value, ValueChanged<String> onChanged) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlField(
            label: label,
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              style: GlType.body(context, size: 12.5, color: gl.fg1),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                filled: true, fillColor: gl.input,
                enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(GlRadius.md), borderSide: BorderSide(color: gl.border)),
                focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(GlRadius.md), borderSide: BorderSide(color: gl.accent)),
              ),
            ),
          ),
        );

    switch (_op) {
      case _Op.merge:
        return [Text('Merges the input document with a second copy of itself to demonstrate ordered concatenation. In production, add files via the file gateway.', style: GlType.body(context, size: 12, color: gl.fg3))];
      case _Op.split:
        return [field('Ranges (e.g. 1, 2-3)', _ranges, (v) => _ranges = v)];
      case _Op.extract:
        return [field('Pages (comma separated)', _extract, (v) => _extract = v)];
      case _Op.rotate:
        return [GlField(label: 'Quarter turns', child: GlSegmented<int>(value: _turns, segments: const {1: '90°', 2: '180°', 3: '270°'}, onChanged: (v) => setState(() => _turns = v)))];
      case _Op.watermark:
        return [
          field('Watermark text', _watermark, (v) => _watermark = v),
          GlField(
            label: 'Opacity · ${(_opacity * 100).round()}%',
            child: Slider(value: _opacity, min: 0.03, max: 0.4, activeColor: gl.accent, onChanged: (v) => setState(() => _opacity = v)),
          ),
        ];
    }
  }
}

class _OpItem extends StatelessWidget {
  const _OpItem({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(GlRadius.md),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? gl.hover : Colors.transparent,
            borderRadius: const BorderRadius.all(GlRadius.md),
            border: Border(left: BorderSide(color: selected ? gl.accent : Colors.transparent, width: 2)),
          ),
          child: Text(label, style: GlType.body(context, size: 12.5, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? gl.fg1 : gl.fg3)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.content_cut_rounded, size: 34, color: gl.fg4),
        const SizedBox(height: 12),
        Text('Configure an operation and run it', style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 4),
        Text('The processed PDF appears here.', style: GlType.body(context, size: 11.5, color: gl.fg4)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return Center(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: gl.danger.withOpacity(0.07), borderRadius: const BorderRadius.all(GlRadius.lg), border: Border.all(color: gl.danger.withOpacity(0.26))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: gl.danger, size: 28),
          const SizedBox(height: 10),
          Text('Processing failed', style: GlType.body(context, size: 13, weight: FontWeight.w700, color: gl.fg1)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: GlType.body(context, size: 12, color: gl.fg2)),
        ]),
      ),
    );
  }
}
