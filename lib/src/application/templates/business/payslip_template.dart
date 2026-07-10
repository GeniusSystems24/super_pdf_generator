// APPLICATION · templates · business · payslip. Pure Dart.
//
// A monthly payslip: earnings and deductions with a validated net pay
// (net = earnings − deductions).

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/amount_in_words.dart';
import '../support/money_format.dart';
import 'models.dart';

/// A single earning or deduction line.
class PayComponent {
  const PayComponent({required this.label, required this.amount, this.labelAr});
  final String label;
  final String? labelAr;
  final double amount;
}

/// Data for a payslip.
class PayslipData {
  const PayslipData({
    required this.employer,
    required this.employee,
    required this.periodLabel,
    required this.earnings,
    required this.deductions,
    this.currency = 'SAR',
    this.employeeId,
    this.payDate,
    this.providedNetPay,
  });

  final PdfParty employer;
  final PdfParty employee;
  final String periodLabel;
  final List<PayComponent> earnings;
  final List<PayComponent> deductions;
  final String currency;
  final String? employeeId;
  final DateTime? payDate;
  final double? providedNetPay;
}

class PayslipTemplate extends PdfTemplate<PayslipData> {
  const PayslipTemplate();

  @override
  String get id => 'payslip';
  @override
  String get name => 'Payslip';
  @override
  String get nameAr => 'قسيمة راتب';
  @override
  String get description => 'Monthly payslip with validated net pay.';

  @override
  GeniusFinancialValidationResult validate(PayslipData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedNetPay == null) return GeniusFinancialValidationResult.valid();
    final gross = data.earnings.fold(0.0, (s, e) => s + e.amount);
    final ded = data.deductions.fold(0.0, (s, e) => s + e.amount);
    return validator.validateGrandTotal(
      subtotal: gross,
      discounts: ded,
      vatAmount: 0,
      fees: 0,
      providedGrandTotal: data.providedNetPay!,
    );
  }

  @override
  PdfDocumentDefinition build(PayslipData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final gross = data.earnings.fold(0.0, (s, e) => s + e.amount);
    final ded = data.deductions.fold(0.0, (s, e) => s + e.amount);
    final net = policy.round(gross - ded);

    List<List<String>> lines(List<PayComponent> cs) => [
          for (final c in cs) [ar ? (c.labelAr ?? c.label) : c.label, fmt(c.amount)],
        ];

    final words = amountInWords(net,
        currencyCode: data.currency,
        language: ar ? AmountWordsLanguage.arabic : AmountWordsLanguage.english,
        fractionDigits: cur.decimalPlaces,);

    return pdfDocument()
        .metadata(title: '${ar ? 'قسيمة راتب' : 'Payslip'} — ${data.periodLabel}', author: data.employer.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'قسيمة راتب' : 'Payslip'),
      pdf.keyValue([
        MapEntry(ar ? 'جهة العمل' : 'Employer', ar ? (data.employer.nameAr ?? data.employer.name) : data.employer.name),
        MapEntry(ar ? 'الموظف' : 'Employee', ar ? (data.employee.nameAr ?? data.employee.name) : data.employee.name),
        if (data.employeeId != null) MapEntry(ar ? 'الرقم الوظيفي' : 'Employee ID', data.employeeId!),
        MapEntry(ar ? 'الفترة' : 'Period', data.periodLabel),
        if (data.payDate != null) MapEntry(ar ? 'تاريخ الصرف' : 'Pay Date', _date(data.payDate!)),
      ]),
      pdf.spacer(12),
      pdf.heading(ar ? 'المستحقات' : 'Earnings', level: 3),
      pdf.dataTable(columns: ar ? ['البند', 'المبلغ'] : ['Item', 'Amount'], rows: lines(data.earnings)),
      pdf.spacer(6),
      pdf.keyValue([MapEntry(ar ? 'إجمالي المستحقات' : 'Total Earnings', fmt(gross))]),
      pdf.spacer(10),
      pdf.heading(ar ? 'الاستقطاعات' : 'Deductions', level: 3),
      pdf.dataTable(columns: ar ? ['البند', 'المبلغ'] : ['Item', 'Amount'], rows: lines(data.deductions)),
      pdf.spacer(6),
      pdf.keyValue([MapEntry(ar ? 'إجمالي الاستقطاعات' : 'Total Deductions', fmt(ded))]),
      pdf.spacer(12),
      pdf.infoBox('${ar ? 'صافي الراتب' : 'Net Pay'}: ${fmt(net)}', tone: 'green'),
      pdf.spacer(4),
      pdf.paragraph('${ar ? 'المبلغ كتابةً' : 'Amount in words'}: $words'),
      pdf.spacer(16),
      pdf.signatureBlock(name: data.employee.name, role: ar ? 'توقيع الموظف' : 'Employee Signature'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
