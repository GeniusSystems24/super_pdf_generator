import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:super_pdf_generator/super_pdf_generator.dart';

import '../../shared/gl_tokens.dart';
import '../../shared/gl_widgets.dart';

/// PDF Preview — renders the builder's current document to real bytes and shows
/// them in the `printing` viewer (page thumbnails, zoom, fit, print, share all
/// provided by the plugin). The same screen backs the Printing destination
/// (`printMode`), where the toolbar's print action is the primary path.
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key, required this.controller, this.printMode = false});
  final BuilderController controller;
  final bool printMode;

  Future<Uint8List> _build() async {
    final request = PdfGenerationRequest(
      fileName: controller.fileName,
      document: controller.document,
      processing: controller.processing,
    );
    final result = await controller.client.toBytes(request);
    return result.fold((bytes) => bytes, (failure) => Uint8List(0));
  }

  @override
  Widget build(BuildContext context) {
    final gl = context.gl;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final seed = '${controller.blocks.length}-${controller.metadata.title}-${controller.direction.name}-${controller.size.name}-${controller.processing.hashCode}';
        return Column(
          children: [
            if (printMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: gl.border))),
                child: Row(children: [
                  GlSectionMarker(gl.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Use the printer icon in the toolbar to print via the platform print gateway (falls back to the browser print dialog on web).',
                        style: GlType.body(context, size: 12, color: gl.fg3)),
                  ),
                ]),
              ),
            Expanded(
              child: Container(
                color: gl.bg,
                child: PdfPreview(
                  key: ValueKey(seed),
                  build: (_) => _build(),
                  useActions: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  loadingWidget: Center(child: CircularProgressIndicator(color: gl.accent)),
                  pdfPreviewPageDecoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  previewPageMargin: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
