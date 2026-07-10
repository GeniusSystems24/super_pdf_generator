// APPLICATION · templates · business · financial reports. Pure Dart.
//
// Balance Sheet, Income Statement (P&L), Cash Flow Statement and Budget vs
// Actual — each recomputes its aggregates with GeniusMoney and enforces the
// relevant accounting identity with GeniusFinancialValidator.

import 'package:super_pdf_generator/src/domain/components.dart';

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';

/// A labelled amount within a report section.
class ReportLine {
  const ReportLine(this.label, this.amount, {this.labelAr});
  final String label;
  final String? labelAr;
  final double amount;
}

/// A named group of [ReportLine]s.
class ReportSection {
  const ReportSection(this.title, this.lines, {this.titleAr});
  final String title;
  final String? titleAr;
  final List<ReportLine> lines;
  double get total => lines.fold(0.0, (s, l) => s + l.amount);
}

// ── Balance Sheet ──

class BalanceSheetData {
  const BalanceSheetData({
    required this.organizationName,
    required this.asOfDate,
    required this.assets,
    required this.liabilities,
    required this.equity,
    this.currency = 'SAR',
    this.organizationNameAr,
  });
  final String organizationName;
  final String? organizationNameAr;
  final DateTime asOfDate;
  final List<ReportSection> assets;
  final List<ReportSection> liabilities;
  final List<ReportSection> equity;
  final String currency;

  double get totalAssets => assets.fold(0.0, (s, x) => s + x.total);
  double get totalLiabilities => liabilities.fold(0.0, (s, x) => s + x.total);
  double get totalEquity => equity.fold(0.0, (s, x) => s + x.total);
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
  String get description => 'Statement of financial position (assets = liabilities + equity).';

  @override
  GeniusFinancialValidationResult validate(BalanceSheetData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final v = GeniusFinancialValidator(ctx.roundingPolicy);
    return v.validateGrandTotal(
      subtotal: data.totalLiabilities,
      discounts: 0,
      vatAmount: data.totalEquity,
      fees: 0,
      providedGrandTotal: data.totalAssets,
    );
  }

  @override
  PdfDocumentDefinition build(BalanceSheetData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final f = _fmt(data.currency, ctx);
    final balanced = GeniusMoney.fromDouble(data.totalAssets, policy: ctx.roundingPolicy).minorUnits ==
        GeniusMoney.fromDouble(data.totalLiabilities + data.totalEquity, policy: ctx.roundingPolicy).minorUnits;

    return _reportDoc(
      ctx: ctx,
      titleEn: 'Balance Sheet',
      titleAr: 'الميزانية العمومية',
      org: ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName,
      dateLabel: '${ar ? 'كما في' : 'As of'}: ${_date(data.asOfDate)}',
      body: [
        ..._sectionsBlock(ar ? 'الأصول' : 'Assets', data.assets, f, ar, ar ? 'إجمالي الأصول' : 'Total Assets', data.totalAssets),
        pdf.spacer(10),
        ..._sectionsBlock(ar ? 'الخصوم' : 'Liabilities', data.liabilities, f, ar, ar ? 'إجمالي الخصوم' : 'Total Liabilities', data.totalLiabilities),
        pdf.spacer(10),
        ..._sectionsBlock(ar ? 'حقوق الملكية' : 'Equity', data.equity, f, ar, ar ? 'إجمالي حقوق الملكية' : 'Total Equity', data.totalEquity),
        pdf.spacer(12),
        pdf.infoBox(
          balanced
              ? (ar ? 'الميزانية متوازنة: الأصول = الخصوم + حقوق الملكية ✓' : 'Balanced: assets = liabilities + equity ✓')
              : (ar ? 'تحذير: الميزانية غير متوازنة' : 'Warning: the balance sheet does NOT balance'),
          tone: balanced ? 'green' : 'red',
        ),
      ],
    );
  }
}

// ── Income Statement ──

class IncomeStatementData {
  const IncomeStatementData({
    required this.organizationName,
    required this.periodLabel,
    required this.revenues,
    required this.expenses,
    this.currency = 'SAR',
    this.organizationNameAr,
    this.providedNetIncome,
  });
  final String organizationName;
  final String? organizationNameAr;
  final String periodLabel;
  final List<ReportLine> revenues;
  final List<ReportLine> expenses;
  final String currency;
  final double? providedNetIncome;

  double get totalRevenue => revenues.fold(0.0, (s, l) => s + l.amount);
  double get totalExpenses => expenses.fold(0.0, (s, l) => s + l.amount);
  double get netIncome => totalRevenue - totalExpenses;
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
  String get description => 'Profit & loss statement (net income = revenue − expenses).';

  @override
  GeniusFinancialValidationResult validate(IncomeStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final v = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedNetIncome == null) return GeniusFinancialValidationResult.valid();
    return v.validateGrandTotal(
      subtotal: data.totalRevenue,
      discounts: data.totalExpenses,
      vatAmount: 0,
      fees: 0,
      providedGrandTotal: data.providedNetIncome!,
    );
  }

  @override
  PdfDocumentDefinition build(IncomeStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final f = _fmt(data.currency, ctx);
    final net = ctx.roundingPolicy.round(data.netIncome);
    return _reportDoc(
      ctx: ctx,
      titleEn: 'Income Statement',
      titleAr: 'قائمة الدخل',
      org: ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName,
      dateLabel: '${ar ? 'الفترة' : 'Period'}: ${data.periodLabel}',
      body: [
        ..._linesBlock(ar ? 'الإيرادات' : 'Revenue', data.revenues, f, ar, ar ? 'إجمالي الإيرادات' : 'Total Revenue', data.totalRevenue),
        pdf.spacer(10),
        ..._linesBlock(ar ? 'المصروفات' : 'Expenses', data.expenses, f, ar, ar ? 'إجمالي المصروفات' : 'Total Expenses', data.totalExpenses),
        pdf.spacer(12),
        pdf.infoBox('${ar ? 'صافي الدخل' : 'Net Income'}: ${f(net)}', tone: net >= 0 ? 'green' : 'red'),
      ],
    );
  }
}

// ── Cash Flow ──

class CashFlowData {
  const CashFlowData({
    required this.organizationName,
    required this.periodLabel,
    required this.operating,
    required this.investing,
    required this.financing,
    required this.openingCash,
    this.currency = 'SAR',
    this.organizationNameAr,
    this.providedClosingCash,
  });
  final String organizationName;
  final String? organizationNameAr;
  final String periodLabel;
  final ReportSection operating;
  final ReportSection investing;
  final ReportSection financing;
  final double openingCash;
  final String currency;
  final double? providedClosingCash;

  double get netChange => operating.total + investing.total + financing.total;
  double get closingCash => openingCash + netChange;
}

class CashFlowTemplate extends PdfTemplate<CashFlowData> {
  const CashFlowTemplate();
  @override
  String get id => 'cash_flow';
  @override
  String get name => 'Cash Flow Statement';
  @override
  String get nameAr => 'قائمة التدفقات النقدية';
  @override
  String get description => 'Operating/investing/financing cash flows with net change.';

  @override
  GeniusFinancialValidationResult validate(CashFlowData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final v = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedClosingCash == null) return GeniusFinancialValidationResult.valid();
    return v.validateGrandTotal(
      subtotal: data.openingCash,
      discounts: 0,
      vatAmount: data.netChange,
      fees: 0,
      providedGrandTotal: data.providedClosingCash!,
    );
  }

  @override
  PdfDocumentDefinition build(CashFlowData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final f = _fmt(data.currency, ctx);
    return _reportDoc(
      ctx: ctx,
      titleEn: 'Cash Flow Statement',
      titleAr: 'قائمة التدفقات النقدية',
      org: ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName,
      dateLabel: '${ar ? 'الفترة' : 'Period'}: ${data.periodLabel}',
      body: [
        pdf.keyValue([MapEntry(ar ? 'النقد الافتتاحي' : 'Opening Cash', f(data.openingCash))]),
        pdf.spacer(8),
        ..._sectionLinesBlock(ar ? 'الأنشطة التشغيلية' : 'Operating Activities', data.operating, f, ar),
        ..._sectionLinesBlock(ar ? 'الأنشطة الاستثمارية' : 'Investing Activities', data.investing, f, ar),
        ..._sectionLinesBlock(ar ? 'الأنشطة التمويلية' : 'Financing Activities', data.financing, f, ar),
        pdf.spacer(10),
        pdf.keyValue([
          MapEntry(ar ? 'صافي التغير في النقد' : 'Net Change in Cash', f(ctx.roundingPolicy.round(data.netChange))),
          MapEntry(ar ? 'النقد الختامي' : 'Closing Cash', f(ctx.roundingPolicy.round(data.closingCash))),
        ]),
      ],
    );
  }
}

// ── Budget vs Actual ──

class BudgetLine {
  const BudgetLine({required this.category, required this.budget, required this.actual, this.categoryAr});
  final String category;
  final String? categoryAr;
  final double budget;
  final double actual;
  double get variance => actual - budget;
  double get variancePct => budget == 0 ? 0 : (actual - budget) / budget.abs() * 100;
}

class BudgetReportData {
  const BudgetReportData({
    required this.organizationName,
    required this.periodLabel,
    required this.lines,
    this.currency = 'SAR',
    this.organizationNameAr,
  });
  final String organizationName;
  final String? organizationNameAr;
  final String periodLabel;
  final List<BudgetLine> lines;
  final String currency;
}

class BudgetReportTemplate extends PdfTemplate<BudgetReportData> {
  const BudgetReportTemplate();
  @override
  String get id => 'budget_report';
  @override
  String get name => 'Budget vs Actual';
  @override
  String get nameAr => 'تقرير الميزانية مقابل الفعلي';
  @override
  String get description => 'Budget vs actual report with per-line variance.';

  @override
  GeniusFinancialValidationResult validate(BudgetReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final v = GeniusFinancialValidator(ctx.roundingPolicy);
    final results = [
      for (final l in data.lines)
        v.validateBudgetVariance(actual: l.actual, budget: l.budget, providedVariance: l.variance),
    ];
    return v.combineResults(results);
  }

  @override
  PdfDocumentDefinition build(BudgetReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final f = _fmt(data.currency, ctx);
    final totBudget = data.lines.fold(0.0, (s, l) => s + l.budget);
    final totActual = data.lines.fold(0.0, (s, l) => s + l.actual);

    final columns = ar
        ? ['البند', 'الميزانية', 'الفعلي', 'الانحراف', '%']
        : ['Category', 'Budget', 'Actual', 'Variance', '%'];
    final rows = <List<String>>[
      for (final l in data.lines)
        [
          ar ? (l.categoryAr ?? l.category) : l.category,
          f(l.budget),
          f(l.actual),
          f(ctx.roundingPolicy.round(l.variance)),
          '${l.variancePct.toStringAsFixed(1)}%',
        ],
      [ar ? 'الإجمالي' : 'TOTAL', f(totBudget), f(totActual), f(ctx.roundingPolicy.round(totActual - totBudget)), ''],
    ];

    return _reportDoc(
      ctx: ctx,
      titleEn: 'Budget vs Actual',
      titleAr: 'الميزانية مقابل الفعلي',
      org: ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName,
      dateLabel: '${ar ? 'الفترة' : 'Period'}: ${data.periodLabel}',
      body: [pdf.dataTable(columns: columns, rows: rows, zebra: true)],
    );
  }
}

// ── shared helpers ──

String Function(double) _fmt(String currency, PdfTemplateContext ctx) {
  final cur = CurrencyFormat.forCode(currency);
  return (v) => formatMoney(GeniusMoney.fromDouble(v, currency: currency, policy: ctx.roundingPolicy), format: cur);
}

PdfDocumentDefinition _reportDoc({
  required PdfTemplateContext ctx,
  required String titleEn,
  required String titleAr,
  required String org,
  required String dateLabel,
  required List<PdfComponent> body,
}) {
  final ar = ctx.isArabic;
  return pdfDocument()
      .metadata(title: ar ? titleAr : titleEn, author: org)
      .direction(ctx.direction)
      .page(size: PdfPageSize.a4, marginsAll: 36)
      .content([
    pdf.header(title: ar ? titleAr : titleEn),
    pdf.heading(org, level: 2),
    pdf.paragraph(dateLabel),
    pdf.spacer(12),
    ...body,
    pdf.spacer(12),
    pdf.pageNumber(),
  ]).build();
}

List<PdfComponent> _linesBlock(String title, List<ReportLine> lines, String Function(double) f, bool ar, String totalLabel, double total) {
  return [
    pdf.heading(title, level: 3),
    pdf.keyValue([
      for (final l in lines) MapEntry(ar ? (l.labelAr ?? l.label) : l.label, f(l.amount)),
      MapEntry(totalLabel, f(total)),
    ]),
  ];
}

List<PdfComponent> _sectionsBlock(String groupTitle, List<ReportSection> sections, String Function(double) f, bool ar, String totalLabel, double total) {
  return [
    pdf.heading(groupTitle, level: 3),
    for (final s in sections) ...[
      pdf.keyValue([
        for (final l in s.lines) MapEntry('  ${ar ? (l.labelAr ?? l.label) : l.label}', f(l.amount)),
        MapEntry(ar ? (s.titleAr ?? s.title) : s.title, f(s.total)),
      ]),
    ],
    pdf.keyValue([MapEntry(totalLabel, f(total))]),
  ];
}

List<PdfComponent> _sectionLinesBlock(String title, ReportSection s, String Function(double) f, bool ar) {
  return [
    pdf.heading(title, level: 3),
    pdf.keyValue([
      for (final l in s.lines) MapEntry(ar ? (l.labelAr ?? l.label) : l.label, f(l.amount)),
      MapEntry(ar ? 'الإجمالي' : 'Subtotal', f(s.total)),
    ]),
    pdf.spacer(6),
  ];
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
