// REPORTS · public barrel.
//
// A self-contained module of reusable, pixel-faithful PDF components and
// document builders that reproduce the GeniusLink financial reports — tax
// invoices, trial balances, customer statements and inventory valuation
// reports — with full LTR/RTL (English/Arabic) parity.
//
// Unlike the generic document-tree renderer in the rest of the SDK, this module
// renders directly with the `pdf` widget layer for precise control over the
// reference layouts (bilingual headers, grouped tables with subtotals, semantic
// summary tints, dark grand-total bands, running footers).
//
// Quick start:
// ```dart
// final reports = await GeniusReports.load();
// final bytes = await reports.taxInvoice(ReportSamples.taxInvoice(),
//     dir: ReportDir.rtl);
// await Printing.layoutPdf(onLayout: (_) => bytes);
// ```

// Theme
export 'theme/report_palette.dart';
export 'theme/report_type_scale.dart';
export 'theme/report_fonts.dart';
export 'theme/report_theme.dart';

// Core
export 'core/report_direction.dart';
export 'core/report_formatting.dart';
export 'core/report_models.dart';

// Components
export 'components/company_header.dart';
export 'components/document_title.dart';
export 'components/info_section.dart';
export 'components/report_data_table.dart';
export 'components/totals_panel.dart';
export 'components/summary_box.dart';
export 'components/signature_row.dart';
export 'components/notes_block.dart';
export 'components/qr_panel.dart';
export 'components/page_footer.dart';

// Documents
export 'documents/report_document.dart';
export 'documents/tax_invoice_report.dart';
export 'documents/trial_balance_report.dart';
export 'documents/customer_statement_report.dart';
export 'documents/inventory_valuation_report.dart';

// Facade + samples
export 'genius_reports.dart';
export 'report_samples.dart';
