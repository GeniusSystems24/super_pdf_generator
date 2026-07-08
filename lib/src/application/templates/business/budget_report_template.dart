// APPLICATION · templates · business · budget report. Pure Dart.
//
// Budget vs actual with per-line variance and variance %, plus validated
// totals. Favourable/unfavourable variance is colour-coded.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';

/// A single budget line: budgeted vs actual.
class BudgetLine {
  const BudgetLine({required this.label, required this.budget, required this.actual, this.labelAr});
  final String label;
  final String? labelAr;
  final double budget;
  final double actual;

  double get variance => actual - budget;
  double get variancePct => budget != 0 ? variance / budget.abs() * 100 : 0;
}

/// Data for a budget report.
class BudgetReportData {
  const BudgetReportData({
    required this.periodLabel,
    required this.lines,
    this.organizationName = '',
    this.organizationNameAr,
    this.currency = 'SAR',
    this.expensesArePositive = true,
  });

  final String periodLabel;
  final List<BudgetLine> lines;
  final String organizationName;
  final String? organizationNameAr;
  final String currency;

  /// When true, a positive variance (actual > budget) is unfavourable
  /// (overspend). Set false for revenue budgets where over is favourable.
  final bool expensesArePositive;

  double get totalBudget => lines.fold(0.0, (s, l) => s + l.budget);
  double get totalActual => lines.fold(0.0, (s, l) => s + l.actual);
  double get totalVariance => totalActual - totalBudget;
}

class BudgetReportTemplate extends PdfTemplate<BudgetReportData> {
  const BudgetReportTemplate();

  @override
  String get id => 'budget_report';
  @override
  String get name => 'Budget Report';
  @override
  String get nameAr => 'تقرير الميزانية';
  @override
  String get description => 'Budget vs actual with variance and variance %.';

  @override
  GeniusFinancialValidationResult validate(BudgetReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    return validator.validateBudgetVariance(
      actual: data.totalActual,
      budget: data.totalBudget,
      providedVariance: data.totalVariance,
    );
  }

  @override
  PdfDocumentDefinition build(BudgetReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final columns = ar
        ? ['البند', 'الميزانية', 'الفعلي', 'الانحراف', '%']
        : ['Item', 'Budget', 'Actual', 'Variance', '%'];
    final rows = <List<String>>[
      for (final l in data.lines)
        [
          ar ? (l.labelAr ?? l.label) : l.label,
          fmt(l.budget),
          fmt(l.actual),
          fmt(l.variance),
          '${l.variancePct.toStringAsFixed(1)}%',
        ],
      [
        ar ? 'الإجمالي' : 'TOTAL',
        fmt(data.totalBudget),
        fmt(data.totalActual),
        fmt(data.totalVariance),
        data.totalBudget != 0 ? '${(data.totalVariance / data.totalBudget.abs() * 100).toStringAsFixed(1)}%' : '—',
      ],
    ];

    final overBudget = data.expensesArePositive
        ? data.totalVariance > 0
        : data.totalVariance < 0;

    return pdfDocument()
        .metadata(title: '${ar ? 'تقرير الميزانية' : 'Budget Report'} — ${data.periodLabel}', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'تقرير الميزانية' : 'Budget vs Actual Report'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'الفترة' : 'Period'}: ${data.periodLabel}'),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox(
        overBudget
            ? (ar ? 'تجاوز في الميزانية: ${fmt(data.totalVariance.abs())}' : 'Over budget by ${fmt(data.totalVariance.abs())}')
            : (ar ? 'ضمن الميزانية: ${fmt(data.totalVariance.abs())}' : 'Within budget by ${fmt(data.totalVariance.abs())}'),
        tone: overBudget ? 'orange' : 'green',
      ),
      pdf.pageNumber(),
    ]).build();
  }
}
