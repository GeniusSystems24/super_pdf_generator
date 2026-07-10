// APPLICATION · intelligence (heuristic, offline). Pure Dart.
//
// The built-in [PdfIntelligence] implementation. It walks the immutable
// document tree and derives structural/content metrics and layout advice with
// zero external dependencies — no network, no model, no plugins — so it is
// deterministic and runs anywhere (including inside an isolate or a unit test).
// A host that wants smarter analysis can implement [PdfIntelligence] itself and
// inject it at the composition root.

import '../domain/components.dart';
import '../domain/document.dart';
import '../domain/intelligence.dart';
import '../domain/value_objects.dart';
import 'contracts.dart';

/// A dependency-free, deterministic content analyzer.
class HeuristicPdfIntelligence implements PdfIntelligence {
  const HeuristicPdfIntelligence();

  static final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _whitespace = RegExp(r'\s+');

  @override
  Future<PdfContentAnalysis> analyze(PdfDocumentDefinition document) async {
    final acc = _Accumulator();
    for (final page in document.pages) {
      for (final component in page.content) {
        _walk(component, acc);
      }
    }
    // Metadata text also counts toward script detection.
    acc.addText(document.metadata.title);
    acc.addText(document.metadata.subject ?? '');

    final words = acc.buffer.isEmpty
        ? 0
        : acc.buffer
            .toString()
            .trim()
            .split(_whitespace)
            .where((w) => w.isNotEmpty)
            .length;
    final pages = document.pages.isEmpty ? 1 : document.pages.length;
    final perPage = words / pages;
    final density = perPage < 120
        ? PdfContentDensity.sparse
        : (perPage > 500 ? PdfContentDensity.dense : PdfContentDensity.balanced);

    final hasAr = acc.arabic;
    final hasLat = acc.latin;
    final script = hasAr && hasLat
        ? PdfScript.mixed
        : hasAr
            ? PdfScript.arabic
            : hasLat
                ? PdfScript.latin
                : PdfScript.unknown;

    return PdfContentAnalysis(
      pageCount: pages,
      wordCount: words,
      characterCount: acc.characters,
      paragraphCount: acc.paragraphs,
      headingCount: acc.headings,
      tableCount: acc.tables,
      imageCount: acc.images,
      listCount: acc.lists,
      script: script,
      density: density,
    );
  }

  @override
  Future<List<PdfLayoutSuggestion>> suggestLayout(
    PdfDocumentDefinition document,
  ) async {
    final analysis = await analyze(document);
    final out = <PdfLayoutSuggestion>[];

    if (analysis.wordCount == 0 && analysis.imageCount == 0) {
      out.add(const PdfLayoutSuggestion(
        severity: PdfSuggestionSeverity.warning,
        code: 'EMPTY_DOCUMENT',
        message: 'The document has no text or images.',
        messageAr: 'المستند لا يحتوي على نص أو صور.',
      ),);
    }
    if (analysis.headingCount == 0 && analysis.paragraphCount >= 3) {
      out.add(const PdfLayoutSuggestion(
        severity: PdfSuggestionSeverity.advice,
        code: 'ADD_HEADINGS',
        message: 'Add headings to break up the text and aid navigation.',
        messageAr: 'أضف عناوين لتقسيم النص وتسهيل التنقل.',
      ),);
    }
    if (analysis.density == PdfContentDensity.dense) {
      out.add(const PdfLayoutSuggestion(
        severity: PdfSuggestionSeverity.advice,
        code: 'REDUCE_DENSITY',
        message:
            'Pages are dense; consider more whitespace, smaller tables or extra pages.',
        messageAr:
            'الصفحات مكتظة؛ فكّر في زيادة المساحات البيضاء أو تصغير الجداول أو إضافة صفحات.',
      ),);
    }
    if (analysis.hasArabic && document.direction == PdfDirection.ltr) {
      out.add(const PdfLayoutSuggestion(
        severity: PdfSuggestionSeverity.warning,
        code: 'SET_RTL',
        message:
            'Arabic content detected but the document direction is LTR. Set RTL.',
        messageAr:
            'تم اكتشاف محتوى عربي لكن اتجاه المستند من اليسار لليمين. اضبط الاتجاه إلى RTL.',
      ),);
    }
    if (analysis.pageCount == 1 && analysis.wordCount > 900) {
      out.add(const PdfLayoutSuggestion(
        severity: PdfSuggestionSeverity.info,
        code: 'CONSIDER_PAGINATION',
        message: 'A single long page may print awkwardly; consider pagination.',
        messageAr: 'قد تُطبع الصفحة الطويلة الواحدة بشكل غير مريح؛ فكّر في التقسيم.',
      ),);
    }
    return out;
  }

  void _walk(PdfComponent component, _Accumulator acc) {
    switch (component) {
      case PdfHeading(:final text):
        acc.headings++;
        acc.addText(text);
      case PdfParagraph(:final text):
        acc.paragraphs++;
        acc.addText(text);
      case PdfText(:final text):
        acc.paragraphs++;
        acc.addText(text);
      case PdfRichText(:final spans):
        acc.paragraphs++;
        for (final s in spans) {
          acc.addText(s);
        }
      case PdfTable(:final columns, :final rows):
        acc.tables++;
        for (final c in columns) {
          acc.addText(c);
        }
        for (final r in rows) {
          for (final cell in r) {
            acc.addText(cell);
          }
        }
      case PdfList(:final items):
        acc.lists++;
        for (final i in items) {
          acc.addText(i);
        }
      case PdfKeyValueSection(:final pairs):
        for (final p in pairs) {
          acc.addText('${p.key} ${p.value}');
        }
      case PdfInfoBox(:final text):
        acc.addText(text);
      case PdfStatusBadge(:final label):
        acc.addText(label);
      case PdfHeader(:final title):
        acc.addText(title);
      case PdfFooter(:final text):
        acc.addText(text);
      case PdfSignatureBlock(:final name, :final role):
        acc.addText('$name $role');
      case PdfImage():
      case PdfSvg():
        acc.images++;
      case PdfContainerBase(:final children):
        for (final child in children) {
          _walk(child, acc);
        }
      default:
        break;
    }
  }
}

/// Mutable tally used while walking the tree.
class _Accumulator {
  final StringBuffer buffer = StringBuffer();
  int characters = 0;
  int paragraphs = 0;
  int headings = 0;
  int tables = 0;
  int images = 0;
  int lists = 0;
  bool arabic = false;
  bool latin = false;

  void addText(String text) {
    if (text.isEmpty) {
      return;
    }
    buffer.write(text);
    buffer.write(' ');
    characters += text.length;
    if (!arabic && HeuristicPdfIntelligence._arabic.hasMatch(text)) {
      arabic = true;
    }
    if (!latin && HeuristicPdfIntelligence._latin.hasMatch(text)) {
      latin = true;
    }
  }
}
