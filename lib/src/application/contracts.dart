// APPLICATION · contracts (ports). Pure Dart interfaces. The application layer
// depends only on these; concrete adapters live in infrastructure and are
// wired at the composition root (dependency inversion).

import 'dart:typed_data';

import '../domain/document.dart';
import '../domain/generation.dart';
import '../domain/processing.dart';

/// Optional context passed to a renderer (fonts already resolved, etc.).
class PdfRenderContext {
  const PdfRenderContext({this.onProgress});
  final void Function(PdfGenerationProgress progress)? onProgress;
}

/// Serializable render request — a document plus its post-processing.
class PdfRenderRequest {
  const PdfRenderRequest({required this.document, required this.processing});
  final PdfDocumentDefinition document;
  final PdfPostProcessing processing;

  Map<String, Object?> toJson() => <String, Object?>{
        'document': document.toJson(),
        'processing': processing.toJson(),
      };

  factory PdfRenderRequest.fromJson(Map<String, Object?> json) =>
      PdfRenderRequest(
        document: PdfDocumentDefinition.fromJson(
            (json['document'] as Map).cast<String, Object?>()),
        processing: PdfPostProcessing.fromJson(
            (json['processing'] as Map).cast<String, Object?>()),
      );
}

/// Raw render output.
class PdfRenderResult {
  const PdfRenderResult({required this.bytes, required this.pageCount});
  final Uint8List bytes;
  final int pageCount;
}

/// The PDF rendering engine port. The one interface every engine implements.
abstract interface class PdfRenderer {
  Future<PdfRenderResult> render(
    PdfRenderRequest request, [
    PdfRenderContext? context,
  ]);

  /// Perform a processing operation (merge/split/rotate/watermark/extract).
  Future<PdfProcessingResult> process(PdfProcessingRequest request);
}

/// Download / persist produced bytes.
abstract interface class FileGateway {
  Future<void> download(PdfGenerationResult result);
  Future<PdfFileReference> save(PdfGenerationResult result, {String? directory});
}

/// Send bytes to a printer (or the platform print dialog).
abstract interface class PrintGateway {
  Future<void> printDocument(PdfGenerationResult result);
}

/// Share bytes via the platform share sheet, where supported.
abstract interface class ShareGateway {
  bool get canShare;
  Future<void> share(PdfGenerationResult result, {String? subject});
}

/// A structured log event.
class LogEvent {
  const LogEvent(this.level, this.message, {this.data});
  final String level; // debug | info | warn | error
  final String message;
  final Map<String, Object?>? data;
}

/// Logging + telemetry sink.
abstract interface class PdfLogger {
  void log(LogEvent event);
}

/// Resolves font bytes for the renderer. Enables custom font registration and
/// Arabic/Latin fallback (mirrors the Web RTL requirements).
abstract interface class FontRegistry {
  Future<Uint8List?> resolve(String family, {bool bold, bool italic});
  void register(String family, Uint8List bytes, {bool bold, bool italic});
}
