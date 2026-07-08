// APPLICATION · templates · business · income statement (P&L). Pure Dart.
//
// Revenue − cost of sales = gross profit; − operating expenses = operating
// income; ± other income/expense − tax = net income. Margins are computed and
// the net income is validated against the recomputed figure.

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

/// Data for an income statement.
class IncomeStatementData {
  const IncomeStatementData({
    required this.periodStart,
    required this.periodEnd,
    required this.revenue,
    required this.costOfSales,
    required this.operatingExpenses,
    this.otherIncome,
    this.otherExpenses,
    this.taxExpense = 0,
    this.organizationName = '',
    this.organizationNameAr,
    this.currency = 'SAR',
    this.providedNetIncome,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final PdfReportSection revenue;
  final PdfReportSection costOfSales;
  final PdfReportSection operatingExpenses;
  final PdfReportSection? otherIncome;
  final PdfReportSection? otherExpenses;
  final double taxExpense;
  final String organizationName;
  final String? organizationNameAr;
  final String currency;
  final double? providedNetIncome;

  double get grossProfit => revenue.total - costOfSales.total;
  double get operatingIncome => grossProfit - operatingExpenses.total;
  double get incomeBeforeTax =>
      operatingIncome + (otherIncome?.total ?? 0) - (otherExpenses?.total ?? 0);
  double get netIncome => incomeBeforeTax - taxExpense;
  double get grossMargin => revenue.total != 0 ? grossProfit / revenue.total * 100 : 0;
  double get netMargin => revenue.total != 0 ? netIncome / revenue.total * 100 : 0;
}

class IncomeStatementTemplate extends PdfTemplate<IncomeStatementData> {
  const IncomeStatementTemplate();

  @override
  String get id => 'income_statement';
  @override
  String get name => 'Income Statement';
  @override
  String get nameAr => 'قائمة الدخل';
  @override
  String get description => 'Profit & loss with gross/operating/net income and margins.';

  @override
  GeniusFinancialValidationResult validate(IncomeStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedNetIncome == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGrandTotal(
      subtotal: data.incomeBeforeTax,
      discounts: data.taxExpense,
      vatAmount: 0,
      fees: 0,
      providedGrandTotal: data.providedNetIncome!,
    );
  }

  @override
  PdfDocumentDefinition build(IncomeStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    List<PdfComponent> section(PdfReportSection s, String totalLabel) => [
          pdf.heading(ar ? (s.titleAr ?? s.title) : s.title, level: 3),
          pdf.dataTable(
            columns: ar ? ['البيان', 'المبلغ'] : ['Description', 'Amount'],
            rows: [
              for (final l in s.lines) ['${'  ' * l.level}${ar ? (l.labelAr ?? l.label) : l.label}', fmt(l.amount)],
              [totalLabel, fmt(s.total)],
            ],
          ),
        ];

    final period = '${_date(data.periodStart)} → ${_date(data.periodEnd)}';

    return pdfDocument()
        .metadata(title: '${ar ? 'قائمة الدخل' : 'Income Statement'} — $period', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'قائمة الدخل' : 'Income Statement'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'للفترة' : 'For the period'}: $period'),
      pdf.spacer(12),
      ...section(data.revenue, ar ? 'إجمالي الإيرادات' : 'Total Revenue'),
      pdf.spacer(6),
      ...section(data.costOfSales, ar ? 'إجمالي تكلفة المبيعات' : 'Total Cost of Sales'),
      pdf.spacer(6),
      pdf.keyValue([MapEntry(ar ? 'إجمالي الربح' : 'Gross Profit', fmt(data.grossProfit))]),
      pdf.spacer(6),
      ...section(data.operatingExpenses, ar ? 'إجمالي المصروفات التشغيلية' : 'Total Operating Expenses'),
      pdf.spacer(6),
      pdf.keyValue([MapEntry(ar ? 'الدخل التشغيلي' : 'Operating Income', fmt(data.operatingIncome))]),
      if (data.otherIncome != null) ...[pdf.spacer(6), ...section(data.otherIncome!, ar ? 'إجمالي الإيرادات الأخرى' : 'Total Other Income')],
      if (data.otherExpenses != null) ...[pdf.spacer(6), ...section(data.otherExpenses!, ar ? 'إجمالي المصروفات الأخرى' : 'Total Other Expenses')],
      pdf.spacer(8),
      pdf.keyValue([
        MapEntry(ar ? 'الدخل قبل الضريبة' : 'Income Before Tax', fmt(data.incomeBeforeTax)),
        if (data.taxExpense != 0) MapEntry(ar ? 'مصروف الضريبة' : 'Tax Expense', fmt(data.taxExpense)),
      ]),
      pdf.spacer(8),
      pdf.infoBox('${ar ? 'صافي الدخل' : 'Net Income'}: ${fmt(data.netIncome)}', tone: data.netIncome >= 0 ? 'green' : 'red'),
      pdf.spacer(6),
      pdf.keyValue([
        MapEntry(ar ? 'هامش الربح الإجمالي' : 'Gross Profit Margin', '${data.grossMargin.toStringAsFixed(2)}%'),
        MapEntry(ar ? 'هامش صافي الربح' : 'Net Profit Margin', '${data.netMargin.toStringAsFixed(2)}%'),
      ]),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
