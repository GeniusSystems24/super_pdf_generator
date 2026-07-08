// APPLICATION · templates · business · cash flow statement. Pure Dart.
//
// Operating / investing / financing activities → net change in cash. Validates
// that opening + net change = closing cash.

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

/// Data for a cash flow statement.
class CashFlowData {
  const CashFlowData({
    required this.periodStart,
    required this.periodEnd,
    required this.operating,
    required this.investing,
    required this.financing,
    required this.openingCash,
    this.organizationName = '',
    this.organizationNameAr,
    this.currency = 'SAR',
    this.providedClosingCash,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final PdfReportSection operating;
  final PdfReportSection investing;
  final PdfReportSection financing;
  final double openingCash;
  final String organizationName;
  final String? organizationNameAr;
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
  String get description => 'Operating / investing / financing → net change in cash.';

  @override
  GeniusFinancialValidationResult validate(CashFlowData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedClosingCash == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGrandTotal(
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
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    List<PdfComponent> section(PdfReportSection s, String totalLabel) => [
          pdf.heading(ar ? (s.titleAr ?? s.title) : s.title, level: 3),
          pdf.dataTable(
            columns: ar ? ['البيان', 'المبلغ'] : ['Activity', 'Amount'],
            rows: [
              for (final l in s.lines) [ar ? (l.labelAr ?? l.label) : l.label, fmt(l.amount)],
              [totalLabel, fmt(s.total)],
            ],
          ),
        ];

    final period = '${_date(data.periodStart)} → ${_date(data.periodEnd)}';

    return pdfDocument()
        .metadata(title: '${ar ? 'قائمة التدفقات النقدية' : 'Cash Flow Statement'} — $period', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'قائمة التدفقات النقدية' : 'Cash Flow Statement'),
      if (data.organizationName.isNotEmpty)
        pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'للفترة' : 'For the period'}: $period'),
      pdf.spacer(12),
      ...section(data.operating, ar ? 'صافي النشاط التشغيلي' : 'Net Operating Activities'),
      pdf.spacer(6),
      ...section(data.investing, ar ? 'صافي النشاط الاستثماري' : 'Net Investing Activities'),
      pdf.spacer(6),
      ...section(data.financing, ar ? 'صافي النشاط التمويلي' : 'Net Financing Activities'),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'صافي التغير في النقد' : 'Net Change in Cash', fmt(data.netChange)),
        MapEntry(ar ? 'النقد الافتتاحي' : 'Opening Cash', fmt(data.openingCash)),
      ]),
      pdf.spacer(6),
      pdf.infoBox('${ar ? 'النقد الختامي' : 'Closing Cash'}: ${fmt(data.closingCash)}', tone: 'blue'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
