// DOMAIN · document definition. Pure, immutable, serializable — a document is
// data, so it can cross an isolate boundary intact (mirrors the Web proposal's
// "serializable by default" and Web-Worker strategy).

import 'package:meta/meta.dart';

import 'components.dart';
import 'theme.dart';
import 'value_objects.dart';

/// Document-level metadata embedded into the PDF.
@immutable
class PdfDocumentMetadata {
  const PdfDocumentMetadata({
    required this.title,
    this.author = '',
    this.subject,
    this.keywords = const <String>[],
  });

  final String title;
  final String author;
  final String? subject;
  final List<String> keywords;

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        'author': author,
        'subject': subject,
        'keywords': keywords,
      };

  factory PdfDocumentMetadata.fromJson(Map<String, Object?> json) =>
      PdfDocumentMetadata(
        title: (json['title'] as String?) ?? 'Document',
        author: (json['author'] as String?) ?? '',
        subject: json['subject'] as String?,
        keywords:
            (json['keywords'] as List?)?.map((e) => e.toString()).toList() ??
                const <String>[],
      );
}

/// A single page's geometry and content.
@immutable
class PdfPageDefinition {
  const PdfPageDefinition({
    this.size = PdfPageSize.a4,
    this.orientation = PdfPageOrientation.portrait,
    this.margins = const PdfMargins.all(36),
    this.content = const <PdfComponent>[],
  });

  final PdfPageSize size;
  final PdfPageOrientation orientation;
  final PdfMargins margins;
  final List<PdfComponent> content;

  PdfPageDefinition copyWith({
    PdfPageSize? size,
    PdfPageOrientation? orientation,
    PdfMargins? margins,
    List<PdfComponent>? content,
  }) =>
      PdfPageDefinition(
        size: size ?? this.size,
        orientation: orientation ?? this.orientation,
        margins: margins ?? this.margins,
        content: content ?? this.content,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'size': size.toJson(),
        'orientation': orientation.name,
        'margins': margins.toJson(),
        'content': content.map((c) => c.toJson()).toList(),
      };

  factory PdfPageDefinition.fromJson(Map<String, Object?> json) =>
      PdfPageDefinition(
        size: json['size'] is Map
            ? PdfPageSize.fromJson((json['size']! as Map).cast<String, Object?>())
            : PdfPageSize.a4,
        orientation: enumByName(PdfPageOrientation.values, json['orientation'],
            PdfPageOrientation.portrait,),
        margins: json['margins'] is Map
            ? PdfMargins.fromJson(
                (json['margins']! as Map).cast<String, Object?>(),)
            : const PdfMargins.all(36),
        content: (json['content'] as List? ?? const [])
            .map((e) => PdfComponent.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );
}

/// The complete, immutable document definition — the primary domain aggregate.
@immutable
class PdfDocumentDefinition {
  const PdfDocumentDefinition({
    required this.metadata,
    this.theme = const PdfTheme(),
    this.pages = const <PdfPageDefinition>[],
    this.direction = PdfDirection.ltr,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Bumped whenever the serialized shape changes; a migrator upgrades older
  /// documents on load (see the Web proposal's versioning strategy).
  static const int currentSchemaVersion = 1;

  final PdfDocumentMetadata metadata;
  final PdfTheme theme;
  final List<PdfPageDefinition> pages;
  final PdfDirection direction;
  final int schemaVersion;

  /// Convenience: every component across every page, in reading order.
  List<PdfComponent> get allComponents =>
      pages.expand((p) => p.content).toList(growable: false);

  /// Aggregate structural validation across all pages.
  List<PdfValidationIssue> validate() {
    final issues = <PdfValidationIssue>[];
    if (metadata.title.trim().isEmpty) {
      issues.add(const PdfValidationIssue('Document title is empty'));
    }
    if (pages.isEmpty) {
      issues.add(const PdfValidationIssue('Document has no pages'));
    }
    for (final p in pages) {
      for (final c in p.content) {
        issues.addAll(c.validate());
      }
    }
    return issues;
  }

  PdfDocumentDefinition copyWith({
    PdfDocumentMetadata? metadata,
    PdfTheme? theme,
    List<PdfPageDefinition>? pages,
    PdfDirection? direction,
  }) =>
      PdfDocumentDefinition(
        metadata: metadata ?? this.metadata,
        theme: theme ?? this.theme,
        pages: pages ?? this.pages,
        direction: direction ?? this.direction,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'metadata': metadata.toJson(),
        'theme': theme.toJson(),
        'direction': direction.name,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory PdfDocumentDefinition.fromJson(Map<String, Object?> json) =>
      PdfDocumentDefinition(
        metadata: PdfDocumentMetadata.fromJson(
            (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),),
        theme: json['theme'] is Map
            ? PdfTheme.fromJson((json['theme']! as Map).cast<String, Object?>())
            : const PdfTheme(),
        direction:
            enumByName(PdfDirection.values, json['direction'], PdfDirection.ltr),
        pages: (json['pages'] as List? ?? const [])
            .map((e) =>
                PdfPageDefinition.fromJson((e as Map).cast<String, Object?>()),)
            .toList(),
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      );
}
