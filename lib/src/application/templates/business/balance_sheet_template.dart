// APPLICATION · templates · business · balance sheet. Pure Dart.
//
// Assets / liabilities / equity statement with the accounting-equation balance
// check (Assets = Liabilities + Equity) enforced by GeniusFinancialValidator.

import 'package:super_pdf_generator/pdf_generator.dart';

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// Data for a balance sheet.
class BalanceSheetData {
  const BalanceSheetData({
    required this.reportDate,
    required this.assets,
    required this.liabilities,
    required this.equity,
    this.organizationName = '',
    this.organizationNameAr,
    this.currency = 'SAR',
    this.notes,
  });

  final DateTime reportDate;
  final PdfReportSection assets;
  final PdfReportSection liabilities;
  final PdfReportSection equity;
  final String organizationName;
  final String? organizationNameAr;
  final String currency;
  final String? notes;

  double get totalAssets => assets.total;
  double get totalLiabilitiesAndEquity => liabilities.total + equity.total;
}

class BalanceSheetTemplate extends PdfTemplate<BalanceSheetData> {
  const BalanceSheetTemplate();

  @override
  String get id => 'balance_sheet';
  @override
  String get name => 'Balance Sheet';
  @override
  String get nameAr => 'الميزانية العمومية';
  @override
  String get description => 'Assets = Liabilities + Equity, with a balance check.';

  @override
  GeniusFinancialValidationResult validate(BalanceSheetData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    return validator.validateGrandTotal(
      subtotal: data.liabilities.total,
      discounts: 0,
      vatAmount: data.equity.total,
      fees: 0,
      providedGrandTotal: data.totalAssets,
    );
  }

  @override
  PdfDocumentDefinition build(BalanceSheetData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final balanced = GeniusMoney.fromDouble(data.totalAssets, policy: policy).minorUnits ==
        GeniusMoney.fromDouble(data.totalLiabilitiesAndEquity, policy: policy).minorUnits;

    return pdfDocument()
        .metadata(title: '${ar ? 'الميزانية العمومية' : 'Balance Sheet'} — ${_date(data.reportDate)}', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'الميزانية العمومية' : 'Balance Sheet'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'كما في' : 'As of'}: ${_date(data.reportDate)}'),
      pdf.spacer(12),
      ..._section(data.assets, ar ? 'إجمالي الأصول' : 'Total Assets', ar, fmt),
      pdf.spacer(8),
      ..._section(data.liabilities, ar ? 'إجمالي الالتزامات' : 'Total Liabilities', ar, fmt),
      pdf.spacer(8),
      ..._section(data.equity, ar ? 'إجمالي حقوق الملكية' : 'Total Equity', ar, fmt),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'إجمالي الالتزامات وحقوق الملكية' : 'Total Liabilities & Equity', fmt(data.totalLiabilitiesAndEquity)),
      ]),
      pdf.spacer(8),
      pdf.infoBox(
        balanced
            ? (ar ? 'الميزانية متوازنة ✓' : 'Balance Sheet is balanced ✓')
            : (ar ? 'تحذير: الميزانية غير متوازنة' : 'Warning: Balance Sheet is NOT balanced'),
        tone: balanced ? 'green' : 'red',
      ),
      if (data.notes != null) ...[pdf.spacer(8), pdf.paragraph(data.notes!)],
      pdf.pageNumber(),
    ]).build();
  }

  List<PdfComponent> _section(PdfReportSection s, String totalLabel, bool ar, String Function(double) fmt) {
    return [
      pdf.heading(ar ? (s.titleAr ?? s.title) : s.title, level: 3),
      pdf.dataTable(
        columns: ar ? ['الكود', 'الحساب', 'المبلغ'] : ['Code', 'Account', 'Amount'],
        rows: [
          for (final l in s.lines)
            [l.code ?? '', '${'  ' * l.level}${ar ? (l.labelAr ?? l.label) : l.label}', fmt(l.amount)],
          ['', totalLabel, fmt(s.total)],
        ],
        zebra: true,
      ),
    ];
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
