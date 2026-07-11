import 'dart:typed_data';

import 'core/report_direction.dart';
import 'documents/customer_statement_report.dart';
import 'documents/inventory_valuation_report.dart';
import 'documents/tax_invoice_report.dart';
import 'documents/trial_balance_report.dart';
import 'theme/report_fonts.dart';
import 'theme/report_palette.dart';
import 'theme/report_theme.dart';
import 'theme/report_type_scale.dart';

/// The kinds of faithful report this library produces.
enum ReportKind {
  taxInvoice('Tax Invoice', 'فاتورة ضريبية'),
  trialBalance('Trial Balance', 'ميزان المراجعة'),
  customerStatement('Customer Statement', 'كشف حساب عميل'),
  inventoryValuation('Inventory Valuation Report', 'تقرير تقييم المخزون');

  const ReportKind(this.label, this.labelAr);
  final String label;
  final String labelAr;

  String labelFor(ReportDir dir) => dir.isRtl ? labelAr : label;
}

/// The single entry point for generating GeniusLink-style report PDFs.
///
/// Load it once (it decodes the bundled Arabic + Latin fonts), then call a
/// document method with your data and a direction. Every method returns raw
/// PDF bytes ready for `Printing.layoutPdf`, `PdfPreview`, a file, or a share
/// sheet.
///
/// ```dart
/// final reports = await GeniusReports.load();
/// final bytes = await reports.taxInvoice(data, dir: ReportDir.rtl);
/// ```
class GeniusReports {
  GeniusReports({
    required this.fonts,
    this.palette = ReportPalette.standard,
    this.scale = ReportTypeScale.standard,
  });

  final ReportFonts fonts;
  final ReportPalette palette;
  final ReportTypeScale scale;

  /// Loads the bundled fonts and returns a ready facade.
  static Future<GeniusReports> load({
    ReportPalette palette = ReportPalette.standard,
    ReportTypeScale scale = ReportTypeScale.standard,
  }) async =>
      GeniusReports(fonts: await ReportFonts.load(), palette: palette, scale: scale);

  /// The composed theme for a direction (exposed for building custom documents
  /// from the individual components).
  ReportTheme themeFor(ReportDir dir) =>
      ReportTheme(fonts: fonts, palette: palette, scale: scale, dir: dir);

  Future<Uint8List> taxInvoice(InvoiceReportData data, {ReportDir dir = ReportDir.ltr}) =>
      TaxInvoiceReport(data, dir: dir).build(themeFor(dir));

  Future<Uint8List> trialBalance(TrialBalanceData data, {ReportDir dir = ReportDir.ltr}) =>
      TrialBalanceReport(data, dir: dir).build(themeFor(dir));

  Future<Uint8List> customerStatement(CustomerStatementData data,
          {ReportDir dir = ReportDir.ltr,}) =>
      CustomerStatementReport(data, dir: dir).build(themeFor(dir));

  Future<Uint8List> inventoryValuation(InventoryReportData data,
          {ReportDir dir = ReportDir.ltr,}) =>
      InventoryValuationReport(data, dir: dir).build(themeFor(dir));
}
