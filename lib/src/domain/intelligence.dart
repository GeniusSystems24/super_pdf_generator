// DOMAIN · intelligence. Pure Dart. No Flutter, no dart:io, no pdf engine, no
// network. Value objects describing an analysis of a document's structure and
// content. Producing them is delegated to a [PdfIntelligence] implementation —
// the built-in one is a dependency-free heuristic that runs entirely offline.

import 'package:meta/meta.dart';

/// Which writing system dominates the document's text.
enum PdfScript { latin, arabic, mixed, unknown }

/// A coarse label for how much content sits on the page.
enum PdfContentDensity { sparse, balanced, dense }

/// A structural + content analysis of a document.
@immutable
class PdfContentAnalysis {
  const PdfContentAnalysis({
    required this.pageCount,
    required this.wordCount,
    required this.characterCount,
    required this.paragraphCount,
    required this.headingCount,
    required this.tableCount,
    required this.imageCount,
    required this.listCount,
    required this.script,
    required this.density,
  });

  final int pageCount;
  final int wordCount;
  final int characterCount;
  final int paragraphCount;
  final int headingCount;
  final int tableCount;
  final int imageCount;
  final int listCount;
  final PdfScript script;
  final PdfContentDensity density;

  bool get hasArabic =>
      script == PdfScript.arabic || script == PdfScript.mixed;

  /// Estimated reading time at ~200 words/minute, always at least one minute
  /// for a non-empty document.
  int get readingMinutes =>
      wordCount == 0 ? 0 : (wordCount / 200).ceil().clamp(1, 1 << 30);

  Map<String, Object?> toJson() => <String, Object?>{
        'pageCount': pageCount,
        'wordCount': wordCount,
        'characterCount': characterCount,
        'paragraphCount': paragraphCount,
        'headingCount': headingCount,
        'tableCount': tableCount,
        'imageCount': imageCount,
        'listCount': listCount,
        'script': script.name,
        'density': density.name,
        'readingMinutes': readingMinutes,
        'hasArabic': hasArabic,
      };
}

/// How strongly a layout suggestion is worded.
enum PdfSuggestionSeverity { info, advice, warning }

/// A single, actionable layout/content suggestion, bilingual.
@immutable
class PdfLayoutSuggestion {
  const PdfLayoutSuggestion({
    required this.severity,
    required this.code,
    required this.message,
    required this.messageAr,
  });

  final PdfSuggestionSeverity severity;

  /// Stable machine code, e.g. 'ADD_HEADINGS'.
  final String code;
  final String message;
  final String messageAr;

  Map<String, Object?> toJson() => <String, Object?>{
        'severity': severity.name,
        'code': code,
        'message': message,
        'messageAr': messageAr,
      };
}
