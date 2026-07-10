// DOMAIN · export. Pure Dart. No Flutter, no dart:io, no pdf engine.
//
// Describes converting an existing PDF into another representation — HTML,
// raster images, plain text, or a PDF/A archival profile. The conversion is
// performed by an infrastructure adapter behind the [PdfExporter] port; this
// layer only models the request and the produced artifacts.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'processing.dart';

/// The target representation of an export.
enum PdfExportFormat { html, image, plainText, pdfA }

/// Raster encoding for image export.
enum PdfRasterFormat { png, jpeg }

/// PDF/A archival conformance level.
enum PdfAConformance { a1b, a2b, a3b }

/// Base type for an export request.
@immutable
sealed class PdfExportRequest {
  const PdfExportRequest({required this.input});

  final PdfInputFile input;

  PdfExportFormat get format;
}

/// Export to a single self-contained HTML file (page images + extracted text).
class PdfHtmlExportRequest extends PdfExportRequest {
  const PdfHtmlExportRequest({
    required super.input,
    this.dpi = 120,
    this.title,
    this.includeText = true,
    this.fileName = 'export.html',
  });

  final double dpi;
  final String? title;
  final bool includeText;
  final String fileName;

  @override
  PdfExportFormat get format => PdfExportFormat.html;
}

/// Export each page (or a subset) to a raster image.
class PdfImageExportRequest extends PdfExportRequest {
  const PdfImageExportRequest({
    required super.input,
    this.dpi = 150,
    this.rasterFormat = PdfRasterFormat.png,
    this.pages = const <int>[],
    this.quality = 90,
  });

  final double dpi;
  final PdfRasterFormat rasterFormat;

  /// 1-based page numbers; empty means every page.
  final List<int> pages;

  /// JPEG quality 1–100 (ignored for PNG).
  final int quality;

  @override
  PdfExportFormat get format => PdfExportFormat.image;
}

/// Extract the document's text content as UTF-8 plain text.
class PdfTextExportRequest extends PdfExportRequest {
  const PdfTextExportRequest({
    required super.input,
    this.perPage = false,
    this.fileName = 'export.txt',
  });

  /// When true, produces one artifact per page; otherwise a single file.
  final bool perPage;
  final String fileName;

  @override
  PdfExportFormat get format => PdfExportFormat.plainText;
}

/// Re-emit the document under a PDF/A archival conformance profile.
class PdfAExportRequest extends PdfExportRequest {
  const PdfAExportRequest({
    required super.input,
    this.conformance = PdfAConformance.a1b,
    this.fileName = 'archive.pdf',
  });

  final PdfAConformance conformance;
  final String fileName;

  @override
  PdfExportFormat get format => PdfExportFormat.pdfA;
}

/// One produced file from an export.
@immutable
class PdfExportArtifact {
  const PdfExportArtifact({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get byteLength => bytes.length;
}

/// The result of an export: one or more artifacts.
@immutable
class PdfExportResult {
  const PdfExportResult({required this.artifacts, required this.format});

  final List<PdfExportArtifact> artifacts;
  final PdfExportFormat format;

  PdfExportArtifact get primary => artifacts.first;
  int get count => artifacts.length;
}
