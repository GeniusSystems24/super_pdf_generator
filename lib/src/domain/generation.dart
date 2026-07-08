// DOMAIN · generation request/result/progress/state. Pure Dart.

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'document.dart';
import 'failures.dart';

/// A request to generate one document.
@immutable
class PdfGenerationRequest {
  const PdfGenerationRequest({
    required this.fileName,
    required this.document,
    this.processing = const PdfPostProcessing(),
    this.preferIsolate = true,
  });

  final String fileName;
  final PdfDocumentDefinition document;

  /// Renderer-applied processing (header/page-numbers/watermark).
  final PdfPostProcessing processing;

  /// Whether to render off the main isolate when possible.
  final bool preferIsolate;

  Map<String, Object?> toJson() => <String, Object?>{
        'fileName': fileName,
        'document': document.toJson(),
        'processing': processing.toJson(),
      };

  factory PdfGenerationRequest.fromJson(Map<String, Object?> json) =>
      PdfGenerationRequest(
        fileName: (json['fileName'] as String?) ?? 'document.pdf',
        document: PdfDocumentDefinition.fromJson(
            (json['document'] as Map? ?? const {}).cast<String, Object?>()),
        processing: json['processing'] is Map
            ? PdfPostProcessing.fromJson(
                (json['processing']! as Map).cast<String, Object?>())
            : const PdfPostProcessing(),
      );
}

/// Where a watermark sits on the page.
enum PdfWatermarkPosition { center, topLeft, topRight, bottomLeft, bottomRight }

/// Page-level processing options applied by the renderer on every page.
@immutable
class PdfPostProcessing {
  const PdfPostProcessing({
    this.header = true,
    this.pageNumbers = true,
    this.watermarkText,
    this.watermarkOpacity = 0.12,
    this.watermarkPosition = PdfWatermarkPosition.center,
  });

  final bool header;
  final bool pageNumbers;
  final String? watermarkText;
  final double watermarkOpacity;
  final PdfWatermarkPosition watermarkPosition;

  bool get hasWatermark =>
      watermarkText != null && watermarkText!.trim().isNotEmpty;

  PdfPostProcessing copyWith({
    bool? header,
    bool? pageNumbers,
    String? watermarkText,
    double? watermarkOpacity,
    PdfWatermarkPosition? watermarkPosition,
    bool clearWatermark = false,
  }) =>
      PdfPostProcessing(
        header: header ?? this.header,
        pageNumbers: pageNumbers ?? this.pageNumbers,
        watermarkText: clearWatermark ? null : (watermarkText ?? this.watermarkText),
        watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
        watermarkPosition: watermarkPosition ?? this.watermarkPosition,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'header': header,
        'pageNumbers': pageNumbers,
        'watermarkText': watermarkText,
        'watermarkOpacity': watermarkOpacity,
        'watermarkPosition': watermarkPosition.name,
      };

  factory PdfPostProcessing.fromJson(Map<String, Object?> json) =>
      PdfPostProcessing(
        header: json['header'] as bool? ?? true,
        pageNumbers: json['pageNumbers'] as bool? ?? true,
        watermarkText: json['watermarkText'] as String?,
        watermarkOpacity: (json['watermarkOpacity'] as num?)?.toDouble() ?? 0.12,
        watermarkPosition: _wm(json['watermarkPosition']),
      );

  static PdfWatermarkPosition _wm(Object? n) {
    for (final v in PdfWatermarkPosition.values) {
      if (v.name == n) return v;
    }
    return PdfWatermarkPosition.center;
  }
}

/// A successful generation result: the raw bytes plus summary metrics.
@immutable
class PdfGenerationResult {
  const PdfGenerationResult({
    required this.bytes,
    required this.fileName,
    required this.pageCount,
    required this.elapsed,
  });

  final Uint8List bytes;
  final String fileName;
  final int pageCount;
  final Duration elapsed;

  int get byteLength => bytes.length;
}

/// A progress tick emitted during generation.
@immutable
class PdfGenerationProgress {
  const PdfGenerationProgress({required this.fraction, this.note});
  final double fraction; // 0..1
  final String? note;
}

/// A reference to a file produced or saved by a gateway.
@immutable
class PdfFileReference {
  const PdfFileReference({required this.name, this.uri, this.byteLength});
  final String name;
  final String? uri;
  final int? byteLength;
}

/// The discriminated generation state — the exact analogue of the Web
/// `PdfGenerationState` union. Exhaustive under `switch`.
@immutable
sealed class PdfGenerationState {
  const PdfGenerationState();
}

class PdfGenIdle extends PdfGenerationState {
  const PdfGenIdle();
}

class PdfGenPreparing extends PdfGenerationState {
  const PdfGenPreparing(this.progress);
  final double progress;
}

class PdfGenGenerating extends PdfGenerationState {
  const PdfGenGenerating(this.progress);
  final double progress;
}

class PdfGenCompleted extends PdfGenerationState {
  const PdfGenCompleted(this.result);
  final PdfGenerationResult result;
}

class PdfGenFailed extends PdfGenerationState {
  const PdfGenFailed(this.error);
  final PdfFailure error;
}

class PdfGenCancelled extends PdfGenerationState {
  const PdfGenCancelled();
}
