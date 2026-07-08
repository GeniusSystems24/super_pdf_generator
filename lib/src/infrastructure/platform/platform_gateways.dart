// INFRASTRUCTURE · platform gateways.
//
// Concrete adapters for delivery, implemented with the `printing` plugin so
// they work across mobile, desktop and web without `dart:io`. Swap these at the
// composition root for platform-specific behaviour (e.g. a documents-directory
// file gateway on mobile/desktop).

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import '../../application/contracts.dart';
import '../../domain/generation.dart';

/// Sends the document to the OS print pipeline (or browser print on web).
class PrintingPrintGateway implements PrintGateway {
  const PrintingPrintGateway();

  @override
  Future<void> printDocument(PdfGenerationResult result) => Printing.layoutPdf(
        name: result.fileName,
        onLayout: (PdfPageFormat _) async => result.bytes,
      );
}

/// Shares the document via the platform share sheet where available.
class PrintingShareGateway implements ShareGateway {
  const PrintingShareGateway();

  @override
  bool get canShare => true;

  @override
  Future<void> share(PdfGenerationResult result, {String? subject}) =>
      Printing.sharePdf(bytes: result.bytes, filename: result.fileName);
}

/// Portable "download/save" via the share sheet — on web this triggers a
/// browser download; on mobile/desktop it opens the save/share dialog.
class SharePdfFileGateway implements FileGateway {
  const SharePdfFileGateway();

  @override
  Future<void> download(PdfGenerationResult result) =>
      Printing.sharePdf(bytes: result.bytes, filename: result.fileName);

  @override
  Future<PdfFileReference> save(PdfGenerationResult result,
      {String? directory}) async {
    await Printing.sharePdf(bytes: result.bytes, filename: result.fileName);
    return PdfFileReference(name: result.fileName, byteLength: result.bytes.length);
  }
}
