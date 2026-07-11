import 'package:flutter/material.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// A small sample document used to exercise the security / export / analysis
/// APIs without depending on the live builder state.
PdfDocumentDefinition _sampleDoc() => pdfDocument()
    .metadata(title: 'Sample Report', author: 'Folio')
    .content([
      pdf.heading('Quarterly Report'),
      pdf.paragraph(
          'A short sample document used to exercise the SDK APIs at runtime.'),
      pdf.table(columns: const [
        'Item',
        'Qty',
        'Total'
      ], rows: const [
        ['Design license', '1', '1,200.00'],
        ['Integration support', '12', '1,800.00'],
      ]),
      pdf.barcode('FOLIO-2042', symbology: 'code128'),
    ])
    .build();

// ============================================================================
// SECURITY  (client.secure / client.unlock)
// ============================================================================

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, required this.client});
  final PdfClient client;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _userPw = TextEditingController(text: 'open-sesame');
  final _ownerPw = TextEditingController(text: 'owner-secret');
  PdfEncryptionAlgorithm _algo = PdfEncryptionAlgorithm.aesx256;
  final Set<PdfDocumentPermission> _perms = {
    PdfDocumentPermission.print,
    PdfDocumentPermission.copyContent,
  };
  bool _busy = false;
  String? _out;
  bool _ok = false;

  @override
  void dispose() {
    _userPw.dispose();
    _ownerPw.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _out = null;
    });
    final gen = await widget.client.generate(
        PdfGenerationRequest(fileName: 'sample.pdf', document: _sampleDoc()));
    final msg = await gen.fold<Future<String>>((ok) async {
      final res = await widget.client.secure(PdfSecurityRequest(
        input: PdfInputFile(name: 'sample.pdf', bytes: ok.bytes),
        options: PdfSecurityOptions(
          userPassword: _userPw.text.isEmpty ? null : _userPw.text,
          ownerPassword: _ownerPw.text.isEmpty ? null : _ownerPw.text,
          algorithm: _algo,
          permissions: _perms,
        ),
      ));
      return res.fold(
        (s) {
          _ok = true;
          return 'Encrypted ${s.bytes.length} bytes · ${s.algorithm.name} · '
              '${_perms.length} permission(s) granted';
        },
        (f) {
          _ok = false;
          return '${f.code} — ${f.message}';
        },
      );
    }, (f) async {
      _ok = false;
      return 'Generate failed: ${f.code}';
    });
    if (mounted) {
      setState(() {
        _busy = false;
        _out = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Extend · Security'),
        const SizedBox(height: 4),
        Text('Document security', style: GlType.display(context, size: 24)),
        const SizedBox(height: 4),
        Text(
            'Encrypt a PDF and restrict permissions via client.secure(); remove protection with client.unlock(). Passwords are redacted in PdfSecurityOptions.toJson().',
            style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: GlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GlSectionHeader(markerColor: gl.accent, title: 'Encryption options'),
                const SizedBox(height: 14),
                _label(context, 'USER PASSWORD (open)'),
                _input(context, _userPw),
                const SizedBox(height: 12),
                _label(context, 'OWNER PASSWORD (full control)'),
                _input(context, _ownerPw),
                const SizedBox(height: 14),
                GlField(
                  label: 'Algorithm',
                  child: GlSegmented<PdfEncryptionAlgorithm>(
                    value: _algo,
                    segments: const {
                      PdfEncryptionAlgorithm.aesx128: 'AES-128',
                      PdfEncryptionAlgorithm.aesx256: 'AES-256',
                    },
                    onChanged: (v) => setState(() => _algo = v),
                  ),
                ),
                const SizedBox(height: 14),
                _label(context, 'PERMISSIONS'),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in PdfDocumentPermission.values)
                    _permChip(context, p),
                ]),
                const SizedBox(height: 18),
                GlGhostButton(
                  label: _busy ? 'Encrypting…' : 'Protect sample document',
                  icon: Icons.lock_outline_rounded,
                  onPressed: _busy ? null : _run,
                ),
                if (_out != null) ...[
                  const SizedBox(height: 14),
                  _resultBox(context, _out!, _ok),
                ],
              ]),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 260,
            child: GlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AVAILABILITY', style: GlType.label(context).copyWith(fontSize: 9.5)),
                const SizedBox(height: 10),
                _avail(context, 'client.canSecure', widget.client.canSecure),
                const SizedBox(height: 14),
                Text('API', style: GlType.label(context).copyWith(fontSize: 9.5)),
                const SizedBox(height: 8),
                _code(context,
                    'await client.secure(\n  PdfSecurityRequest(\n    input: input,\n    options: PdfSecurityOptions(\n      userPassword: …,\n      algorithm: aesx256,\n    ),\n  ),\n);'),
              ]),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _permChip(BuildContext context, PdfDocumentPermission p) {
    final gl = context.gl;
    final on = _perms.contains(p);
    return InkWell(
      borderRadius: GlRadius.pill,
      onTap: () => setState(() => on ? _perms.remove(p) : _perms.add(p)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? gl.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: GlRadius.pill,
          border: Border.all(color: on ? gl.accent : gl.border),
        ),
        child: Text(p.name,
            style: GlType.body(context, size: 11, color: on ? gl.accent : gl.fg3)),
      ),
    );
  }
}

// ============================================================================
// EXPORT  (client.export)
// ============================================================================

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.client});
  final PdfClient client;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  PdfExportFormat _format = PdfExportFormat.image;
  bool _busy = false;
  String? _out;
  bool _ok = false;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _out = null;
    });
    final gen = await widget.client.generate(
        PdfGenerationRequest(fileName: 'sample.pdf', document: _sampleDoc()));
    final msg = await gen.fold<Future<String>>((ok) async {
      final input = PdfInputFile(name: 'sample.pdf', bytes: ok.bytes);
      final request = switch (_format) {
        PdfExportFormat.html => PdfHtmlExportRequest(input: input),
        PdfExportFormat.image => PdfImageExportRequest(input: input, dpi: 120),
        PdfExportFormat.plainText => PdfTextExportRequest(input: input),
        PdfExportFormat.pdfA => PdfAExportRequest(input: input),
      };
      final res = await widget.client.export(request);
      return res.fold(
        (r) {
          _ok = true;
          final a = r.primary;
          return '${r.count} artifact(s) · ${a.name} · ${a.mimeType} · ${a.byteLength} bytes';
        },
        (f) {
          _ok = false;
          return '${f.code} — ${f.message}';
        },
      );
    }, (f) async {
      _ok = false;
      return 'Generate failed: ${f.code}';
    });
    if (mounted) {
      setState(() {
        _busy = false;
        _out = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Extend · Export'),
        const SizedBox(height: 4),
        Text('Export pipeline', style: GlType.display(context, size: 24)),
        const SizedBox(height: 4),
        Text(
            'Convert an existing PDF to HTML, raster images (PNG/JPEG), plain text, or a PDF/A archival profile via client.export().',
            style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 18),
        GlCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GlSectionHeader(markerColor: gl.accent, title: 'Target format'),
            const SizedBox(height: 14),
            GlSegmented<PdfExportFormat>(
              value: _format,
              segments: const {
                PdfExportFormat.html: 'HTML',
                PdfExportFormat.image: 'Image',
                PdfExportFormat.plainText: 'Text',
                PdfExportFormat.pdfA: 'PDF/A',
              },
              onChanged: (v) => setState(() => _format = v),
            ),
            const SizedBox(height: 12),
            Text(_formatBlurb(_format),
                style: GlType.body(context, size: 12, color: gl.fg3)),
            const SizedBox(height: 16),
            GlGhostButton(
              label: _busy ? 'Exporting…' : 'Export sample document',
              icon: Icons.file_download_outlined,
              onPressed: _busy ? null : _run,
            ),
            if (_out != null) ...[
              const SizedBox(height: 14),
              _resultBox(context, _out!, _ok),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        GlCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AVAILABILITY', style: GlType.label(context).copyWith(fontSize: 9.5)),
            const SizedBox(height: 10),
            _avail(context, 'client.canExport', widget.client.canExport),
          ]),
        ),
      ],
    );
  }

  String _formatBlurb(PdfExportFormat f) => switch (f) {
        PdfExportFormat.html =>
          'A self-contained HTML file: one page image per page, plus extracted text.',
        PdfExportFormat.image =>
          'One raster image per page (PNG or JPEG) at the requested DPI.',
        PdfExportFormat.plainText =>
          'The document text, extracted with the Syncfusion text extractor.',
        PdfExportFormat.pdfA =>
          'The document re-emitted under a PDF/A archival conformance profile.',
      };
}

// ============================================================================
// INTELLIGENCE  (client.analyze / client.suggestLayout)
// ============================================================================

class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key, required this.client});
  final PdfClient client;

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  bool _busy = false;
  PdfContentAnalysis? _analysis;
  List<PdfLayoutSuggestion> _suggestions = const [];
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final doc = _sampleDoc();
    final a = await widget.client.analyze(doc);
    final s = await widget.client.suggestLayout(doc);
    if (!mounted) return;
    setState(() {
      _busy = false;
      a.fold((ok) => _analysis = ok, (f) => _error = '${f.code} — ${f.message}');
      s.fold((ok) => _suggestions = ok, (f) => _error = '${f.code} — ${f.message}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    final a = _analysis;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlEyebrow('Extend · Intelligence'),
        const SizedBox(height: 4),
        Text('Content intelligence', style: GlType.display(context, size: 24)),
        const SizedBox(height: 4),
        Text(
            'client.analyze() reports structure & content metrics; client.suggestLayout() returns bilingual advice. The default analyzer is a dependency-free heuristic that runs entirely offline.',
            style: GlType.body(context, size: 13, color: gl.fg3)),
        const SizedBox(height: 16),
        GlGhostButton(
          label: _busy ? 'Analyzing…' : 'Analyze sample document',
          icon: Icons.insights_rounded,
          onPressed: _busy ? null : _run,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _resultBox(context, _error!, false),
        ],
        if (a != null) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GlStatCard(label: 'Words', value: '${a.wordCount}', sub: '${a.readingMinutes} min read')),
            const SizedBox(width: 12),
            Expanded(child: GlStatCard(label: 'Script', value: a.script.name, sub: a.hasArabic ? 'Arabic present' : 'Latin')),
            const SizedBox(width: 12),
            Expanded(child: GlStatCard(label: 'Density', value: a.density.name, sub: '${a.pageCount} page(s)')),
            const SizedBox(width: 12),
            Expanded(child: GlStatCard(label: 'Tables', value: '${a.tableCount}', sub: '${a.headingCount} heading(s)')),
          ]),
          const SizedBox(height: 16),
          GlCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlSectionHeader(markerColor: gl.orange, title: 'Layout suggestions · ${_suggestions.length}'),
              const SizedBox(height: 12),
              if (_suggestions.isEmpty)
                Text('No suggestions — the document looks well-structured.',
                    style: GlType.body(context, size: 12.5, color: gl.fg3))
              else
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: switch (s.severity) {
                                PdfSuggestionSeverity.warning => gl.danger,
                                PdfSuggestionSeverity.advice => gl.orange,
                                PdfSuggestionSeverity.info => gl.accent,
                              },
                              shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.code, style: GlType.mono(context, size: 10.5, color: gl.fg4)),
                          const SizedBox(height: 2),
                          Text(s.message, style: GlType.body(context, size: 12.5, color: gl.fg1)),
                          Text(s.messageAr,
                              textDirection: TextDirection.rtl,
                              style: GlType.body(context, size: 11.5, color: gl.fg3)),
                        ]),
                      ),
                    ]),
                  ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// shared bits
// ============================================================================

Widget _label(BuildContext context, String s) =>
    Text(s, style: GlType.label(context, color: context.gl.fg4).copyWith(fontSize: 9));

Widget _input(BuildContext context, TextEditingController c) {
  final gl = context.gl;
  return Padding(
    padding: const EdgeInsets.only(top: 5),
    child: TextField(
      controller: c,
      style: GlType.mono(context, size: 12, color: gl.fg1),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        filled: true,
        fillColor: gl.input,
        enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(GlRadius.md),
            borderSide: BorderSide(color: gl.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(GlRadius.md),
            borderSide: BorderSide(color: gl.accent)),
      ),
    ),
  );
}

Widget _avail(BuildContext context, String label, bool ok) {
  final gl = context.gl;
  return Row(children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(color: ok ? gl.green : gl.fg4, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: GlType.mono(context, size: 11, color: gl.fg2))),
    Text(ok ? 'ready' : 'off', style: GlType.body(context, size: 11, color: ok ? gl.green : gl.fg4)),
  ]);
}

Widget _resultBox(BuildContext context, String text, bool ok) {
  final gl = context.gl;
  final col = ok ? gl.green : gl.danger;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: col.withOpacity(0.08),
      borderRadius: const BorderRadius.all(GlRadius.md),
      border: Border.all(color: col.withOpacity(0.3)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, size: 15, color: col),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: GlType.mono(context, size: 11.5, color: gl.fg1))),
    ]),
  );
}

Widget _code(BuildContext context, String code) {
  final gl = context.gl;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: const Color(0xFF0E0F13),
        borderRadius: const BorderRadius.all(GlRadius.md),
        border: Border.all(color: gl.border)),
    child: SelectableText(code,
        style: GlType.mono(context, size: 10.5, color: const Color(0xFFC3C6D7)).copyWith(height: 1.6)),
  );
}
