// DOMAIN · processing requests. Pure Dart. Merge / split / extract / rotate /
// watermark — each a serializable request the renderer can execute.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'generation.dart';

/// Bytes of an input PDF to be processed, plus a display name.
@immutable
class PdfInputFile {
  const PdfInputFile({required this.name, required this.bytes, this.pageCount});
  final String name;
  final Uint8List bytes;
  final int? pageCount;
}

/// Base for all processing operations.
@immutable
sealed class PdfProcessingRequest {
  const PdfProcessingRequest();
  String get operation;
}

/// Merge several PDFs into one, in the given order.
class PdfMergeRequest extends PdfProcessingRequest {
  const PdfMergeRequest({required this.inputs, this.fileName = 'merged.pdf'});
  final List<PdfInputFile> inputs;
  final String fileName;
  @override
  String get operation => 'merge';
}

/// Split one PDF into ranges (each range becomes a document).
class PdfSplitRequest extends PdfProcessingRequest {
  const PdfSplitRequest({required this.input, required this.ranges});
  final PdfInputFile input;
  final List<PdfPageRange> ranges;
  @override
  String get operation => 'split';
}

/// Extract a set of pages into a single new document.
class PdfExtractPagesRequest extends PdfProcessingRequest {
  const PdfExtractPagesRequest({
    required this.input,
    required this.pages,
    this.fileName = 'extract.pdf',
  });
  final PdfInputFile input;
  final List<int> pages; // 1-based
  final String fileName;
  @override
  String get operation => 'extractPages';
}

/// Rotate selected pages by a multiple of 90°.
class PdfRotatePagesRequest extends PdfProcessingRequest {
  const PdfRotatePagesRequest({
    required this.input,
    required this.pages,
    required this.quarterTurns,
  });
  final PdfInputFile input;
  final List<int> pages; // 1-based; empty = all
  final int quarterTurns; // 1..3
  @override
  String get operation => 'rotate';
}

/// Stamp a watermark (text or image) onto every page.
class PdfWatermarkRequest extends PdfProcessingRequest {
  const PdfWatermarkRequest({
    required this.input,
    this.text,
    this.imageAssetKey,
    this.opacity = 0.12,
    this.position = PdfWatermarkPosition.center,
  });
  final PdfInputFile input;
  final String? text;
  final String? imageAssetKey;
  final double opacity;
  final PdfWatermarkPosition position;
  @override
  String get operation => 'watermark';
}

/// An inclusive 1-based page range.
@immutable
class PdfPageRange {
  const PdfPageRange(this.start, this.end);
  final int start;
  final int end;
  bool contains(int page) => page >= start && page <= end;
  Map<String, Object?> toJson() => {'start': start, 'end': end};
}

/// The result of a processing operation: one or more produced files.
@immutable
class PdfProcessingResult {
  const PdfProcessingResult({required this.outputs, required this.operation});
  final List<PdfGenerationResult> outputs;
  final String operation;
  PdfGenerationResult get primary => outputs.first;
}
