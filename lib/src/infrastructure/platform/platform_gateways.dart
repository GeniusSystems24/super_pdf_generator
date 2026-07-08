// INFRASTRUCTURE · platform gateways.
//
// Concrete adapters for delivery, implemented with the `printing`, `share_plus`
// and `url_launcher` plugins so they work across mobile, desktop and web
// without `dart:io`. Swap these at the composition root for platform-specific
// behaviour (e.g. a documents-directory file gateway on mobile/desktop).

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/contracts.dart';
import '../../domain/generation.dart';
import '../../domain/printing.dart';
import '../../domain/value_objects.dart';

/// Sends the document to the OS print pipeline (or browser print on web).
/// When a [PrinterDevice] is supplied it prints directly to that device;
/// otherwise it opens the platform print dialog. [PrintSettings] are applied
/// best-effort (paper size is honoured; copies/duplex surface in the dialog).
class PrintingPrintGateway implements PrintGateway {
  const PrintingPrintGateway();

  @override
  Future<void> printDocument(
    PdfGenerationResult result, {
    PrintSettings? settings,
    PrinterDevice? printer,
  }) async {
    final format = _format(settings);
    if (printer != null) {
      await Printing.directPrintPdf(
        printer: Printer(url: printer.id, name: printer.name),
        onLayout: (PdfPageFormat _) async => result.bytes,
      );
      return;
    }
    await Printing.layoutPdf(
      name: result.fileName,
      format: format,
      onLayout: (PdfPageFormat _) async => result.bytes,
    );
  }

  PdfPageFormat _format(PrintSettings? s) {
    final size = s?.paperSize;
    if (size == null) return PdfPageFormat.standard;
    final oriented = size.oriented(s?.orientation ?? PdfPageOrientation.portrait);
    return PdfPageFormat(oriented.widthPt, oriented.heightPt);
  }
}

/// Enumerates printers via the platform print backend.
class PrintingPrinterDiscovery implements PrinterDiscovery {
  const PrintingPrinterDiscovery();

  @override
  Future<List<PrinterDevice>> listPrinters() async {
    final printers = await Printing.listPrinters();
    return [
      for (final p in printers)
        PrinterDevice(
          id: p.url,
          name: p.name,
          url: p.url,
          model: p.model,
          location: p.location,
          isDefault: p.isDefault,
          isAvailable: p.isAvailable,
        ),
    ];
  }
}

/// Opens a pre-filled email compose window via a `mailto:` URL.
class UrlLauncherEmailGateway implements EmailGateway {
  const UrlLauncherEmailGateway();

  @override
  bool get canEmail => true;

  @override
  Future<void> compose({
    List<String> to = const <String>[],
    String? subject,
    String? body,
    List<String> cc = const <String>[],
  }) async {
    final params = <String>[
      if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
      if (body != null) 'body=${Uri.encodeComponent(body)}',
      if (cc.isNotEmpty) 'cc=${cc.join(',')}',
    ];
    final uri = Uri.parse('mailto:${to.join(',')}${params.isEmpty ? '' : '?${params.join('&')}'}');
    if (!await launchUrl(uri)) {
      throw Exception('No email client is available to handle mailto:');
    }
  }
}

/// Shares the document via the platform share sheet where available — this
/// sheet surfaces email, Bluetooth and installed apps as targets.
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
