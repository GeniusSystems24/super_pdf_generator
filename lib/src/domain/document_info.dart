// DOMAIN · document info. Pure Dart. The result of inspecting an existing PDF.

import 'package:meta/meta.dart';

/// Page geometry in PDF points (1/72 inch).
@immutable
class PdfPageInfo {
  const PdfPageInfo({required this.widthPt, required this.heightPt, this.rotationDegrees = 0});
  final double widthPt;
  final double heightPt;
  final int rotationDegrees;

  bool get isLandscape => widthPt > heightPt;

  Map<String, Object?> toJson() =>
      {'widthPt': widthPt, 'heightPt': heightPt, 'rotationDegrees': rotationDegrees};
}

/// Introspection metadata for an existing PDF document, produced by a
/// [PdfInspector] adapter (Syncfusion in infrastructure).
@immutable
class PdfDocumentInfo {
  const PdfDocumentInfo({
    required this.pageCount,
    this.title,
    this.author,
    this.subject,
    this.keywords = const <String>[],
    this.creator,
    this.producer,
    this.creationDate,
    this.modificationDate,
    this.isEncrypted = false,
    this.byteLength = 0,
    this.pages = const <PdfPageInfo>[],
  });

  final int pageCount;
  final String? title;
  final String? author;
  final String? subject;
  final List<String> keywords;
  final String? creator;
  final String? producer;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final bool isEncrypted;
  final int byteLength;
  final List<PdfPageInfo> pages;

  Map<String, Object?> toJson() => <String, Object?>{
        'pageCount': pageCount,
        'title': title,
        'author': author,
        'subject': subject,
        'keywords': keywords,
        'creator': creator,
        'producer': producer,
        'creationDate': creationDate?.toIso8601String(),
        'modificationDate': modificationDate?.toIso8601String(),
        'isEncrypted': isEncrypted,
        'byteLength': byteLength,
        'pages': pages.map((p) => p.toJson()).toList(),
      };
}
