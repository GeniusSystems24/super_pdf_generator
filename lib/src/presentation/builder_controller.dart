// PRESENTATION · builder controller (presentation model).
//
// The Flutter analogue of the Web `BuilderController` + `useBuilder` hook. It
// owns editable builder state and calls the application use cases through the
// [PdfClient]; the View (widgets) only reads its fields and invokes its
// methods. It may use `package:flutter/foundation` (ChangeNotifier) — the
// architectural boundary test forbids Flutter in domain/application, not here.

import 'package:flutter/foundation.dart';

import '../application/builder.dart';
import '../application/pdf_client.dart';
import '../domain/components.dart';
import '../domain/document.dart';
import '../domain/failures.dart';
import '../domain/generation.dart';
import '../domain/theme.dart';
import '../domain/value_objects.dart';

/// An identified block in the working document — gives the editor stable
/// identity without polluting the pure, id-less domain components.
@immutable
class BuilderBlock {
  const BuilderBlock(this.id, this.component);
  final String id;
  final PdfComponent component;
}

class BuilderController extends ChangeNotifier {
  BuilderController(this._client) {
    seedSample();
  }

  final PdfClient _client;
  PdfClient get client => _client;

  // ---- editable state ----------------------------------------------------
  PdfDocumentMetadata metadata =
      const PdfDocumentMetadata(title: 'Invoice INV-2042', author: 'GeniusLink');
  PdfPageSize size = PdfPageSize.a4;
  PdfPageOrientation orientation = PdfPageOrientation.portrait;
  PdfMargins margins = const PdfMargins.all(36);
  PdfDirection direction = PdfDirection.ltr;
  PdfColor accent = PdfColor.accent;
  PdfPostProcessing processing = const PdfPostProcessing();

  final List<BuilderBlock> _blocks = <BuilderBlock>[];
  List<BuilderBlock> get blocks => List.unmodifiable(_blocks);

  String? _selectedId;
  String? get selectedId => _selectedId;
  BuilderBlock? get selected {
    for (final b in _blocks) {
      if (b.id == _selectedId) return b;
    }
    return null;
  }

  PdfGenerationState generation = const PdfGenIdle();
  PdfGenerationResult? lastResult;

  int _seq = 0;
  String _nextId() => 'b${_seq++}';

  // ---- document assembly -------------------------------------------------

  /// The immutable, serializable document assembled from the current state.
  PdfDocumentDefinition get document => pdfDocument()
      .metadata(title: metadata.title, author: metadata.author)
      .theme(PdfTheme(
        palette: PdfPalette(accent: accent),
        direction: direction,
        variant: direction == PdfDirection.rtl ? 'rtl' : 'light',
      ),)
      .direction(direction)
      .page(size: size, orientation: orientation, margins: margins)
      .content(_blocks.map((b) => b.component).toList())
      .build();

  List<PdfValidationIssue> get issues => document.validate();

  String get fileName {
    final slug = metadata.title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-|-\$'), '');
    return '${slug.isEmpty ? 'document' : slug}.pdf';
  }

  // ---- editing -----------------------------------------------------------

  void add(PdfComponent component) {
    final block = BuilderBlock(_nextId(), component);
    _blocks.add(block);
    _selectedId = block.id;
    notifyListeners();
  }

  void replace(String id, PdfComponent next) {
    final i = _blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _blocks[i] = BuilderBlock(id, next);
    notifyListeners();
  }

  void remove(String id) {
    _blocks.removeWhere((b) => b.id == id);
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void duplicate(String id) {
    final i = _blocks.indexWhere((b) => b.id == id);
    if (i < 0) return;
    final copy = BuilderBlock(_nextId(), _blocks[i].component);
    _blocks.insert(i + 1, copy);
    _selectedId = copy.id;
    notifyListeners();
  }

  void move(String id, int delta) {
    final i = _blocks.indexWhere((b) => b.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= _blocks.length) return;
    final block = _blocks.removeAt(i);
    _blocks.insert(j, block);
    notifyListeners();
  }

  void select(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  void setMetadata({String? title, String? author}) {
    metadata = PdfDocumentMetadata(
      title: title ?? metadata.title,
      author: author ?? metadata.author,
    );
    notifyListeners();
  }

  void setPage({PdfPageSize? size, PdfPageOrientation? orientation, double? marginsAll}) {
    if (size != null) this.size = size;
    if (orientation != null) this.orientation = orientation;
    if (marginsAll != null) margins = PdfMargins.all(marginsAll);
    notifyListeners();
  }

  void setDirection(PdfDirection value) {
    direction = value;
    notifyListeners();
  }

  void setAccent(PdfColor value) {
    accent = value;
    notifyListeners();
  }

  void setProcessing(PdfPostProcessing value) {
    processing = value;
    notifyListeners();
  }

  void clear() {
    _blocks.clear();
    _selectedId = null;
    notifyListeners();
  }

  void seedSample() {
    _blocks
      ..clear()
      ..addAll(<BuilderBlock>[
        BuilderBlock(_nextId(), pdf.heading('Invoice', level: 1)),
        BuilderBlock(
            _nextId(),
            pdf.paragraph(
                'Prepared for Northwind Trading LLC. Payment is due within 30 days of the issue date shown below.',),),
        BuilderBlock(
            _nextId(),
            pdf.keyValue(const [
              MapEntry('Invoice No', 'INV-2042'),
              MapEntry('Date', '2026-02-14'),
              MapEntry('Terms', 'Net 30'),
            ]),),
        BuilderBlock(_nextId(), pdf.divider()),
        BuilderBlock(
            _nextId(),
            pdf.table(columns: const [
              'Description',
              'Qty',
              'Unit',
              'Amount',
            ], rows: const [
              ['Design system license', '1', '1,200', '1,200'],
              ['Integration support', '12', '150', '1,800'],
              ['Onboarding workshop', '1', '900', '900'],
            ],),),
        BuilderBlock(_nextId(), pdf.spacer(10)),
        BuilderBlock(
            _nextId(),
            pdf.keyValue(const [
              MapEntry('Subtotal', '3,900.00'),
              MapEntry('VAT 15%', '585.00'),
              MapEntry('Total', 'SAR 4,485.00'),
            ]),),
        BuilderBlock(
            _nextId(), pdf.statusBadge(label: 'AWAITING PAYMENT', tone: 'orange'),),
      ]);
    _selectedId = _blocks.first.id;
    notifyListeners();
  }

  // ---- library actions ---------------------------------------------------

  Future<void> generate() async {
    generation = const PdfGenPreparing(0);
    notifyListeners();
    final request = PdfGenerationRequest(
      fileName: fileName,
      document: document,
      processing: processing,
    );
    generation = const PdfGenGenerating(0);
    notifyListeners();
    final result = await _client.generate(
      request,
      onProgress: (p) {
        generation = PdfGenGenerating(p.fraction);
        notifyListeners();
      },
    );
    result.fold(
      (value) {
        lastResult = value;
        generation = PdfGenCompleted(value);
      },
      (failure) => generation = PdfGenFailed(failure),
    );
    notifyListeners();
  }

  Future<Result<void>> download() async {
    final r = lastResult;
    if (r == null) {
      await generate();
      final r2 = lastResult;
      if (r2 == null) return Result.err(generation is PdfGenFailed ? (generation as PdfGenFailed).error : const UnknownFailure(message: 'Nothing to download.'));
      return _client.download(r2);
    }
    return _client.download(r);
  }

  Future<Result<void>> printDocument() async {
    final r = lastResult;
    if (r == null) {
      await generate();
      final r2 = lastResult;
      if (r2 == null) return const Result.err(UnknownFailure(message: 'Nothing to print.'));
      return _client.printDocument(r2);
    }
    return _client.printDocument(r);
  }

  Future<Result<void>> share() async {
    final r = lastResult;
    if (r == null) return const Result.err(UnknownFailure(message: 'Generate first.'));
    return _client.share(r);
  }
}
