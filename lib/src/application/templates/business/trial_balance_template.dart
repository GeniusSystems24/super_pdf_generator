// APPLICATION · templates · business · trial balance. Pure Dart.
//
// An accounting trial balance. Enforces the fundamental invariant that total
// debits equal total credits (exact, no tolerance).

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';

/// A single ledger account row.
class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    this.debit = 0,
    this.credit = 0,
    this.accountNameAr,
  });
  final String accountCode;
  final String accountName;
  final String? accountNameAr;
  final double debit;
  final double credit;
}

/// Data for a trial balance report.
class TrialBalanceData {
  const TrialBalanceData({
    required this.organizationName,
    required this.asOfDate,
    required this.rows,
    this.currency = 'SAR',
    this.organizationNameAr,
  });
  final String organizationName;
  final String? organizationNameAr;
  final DateTime asOfDate;
  final List<TrialBalanceRow> rows;
  final String currency;
}

class TrialBalanceTemplate extends PdfTemplate<TrialBalanceData> {
  const TrialBalanceTemplate();

  @override
  String get id => 'trial_balance';
  @override
  String get name => 'Trial Balance';
  @override
  String get nameAr => 'ميزان المراجعة';
  @override
  String get description => 'Ledger trial balance with debit = credit enforcement.';

  @override
  GeniusFinancialValidationResult validate(TrialBalanceData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    return validator.validateAccountingEntries(
      debits: data.rows.map((r) => r.debit).toList(),
      credits: data.rows.map((r) => r.credit).toList(),
    );
  }

  @override
  PdfDocumentDefinition build(TrialBalanceData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) => v == 0
        ? '—'
        : formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final totalDebit = policy.round(data.rows.fold(0.0, (s, r) => s + r.debit));
    final totalCredit = policy.round(data.rows.fold(0.0, (s, r) => s + r.credit));
    final balanced = GeniusMoney.fromDouble(totalDebit, policy: policy).minorUnits ==
        GeniusMoney.fromDouble(totalCredit, policy: policy).minorUnits;

    final columns = ar
        ? ['الرمز', 'اسم الحساب', 'مدين', 'دائن']
        : ['Code', 'Account', 'Debit', 'Credit'];
    final rows = <List<String>>[
      for (final r in data.rows)
        [r.accountCode, ar ? (r.accountNameAr ?? r.accountName) : r.accountName, fmt(r.debit), fmt(r.credit)],
      [
        '',
        ar ? 'الإجمالي' : 'TOTAL',
        formatMoney(GeniusMoney.fromDouble(totalDebit, currency: data.currency, policy: policy), format: cur),
        formatMoney(GeniusMoney.fromDouble(totalCredit, currency: data.currency, policy: policy), format: cur),
      ],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? 'ميزان المراجعة' : 'Trial Balance'} — ${_date(data.asOfDate)}', author: data.organizationName)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.portrait, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'ميزان المراجعة' : 'Trial Balance'),
      pdf.heading(ar ? (data.organizationNameAr ?? data.organizationName) : data.organizationName, level: 2),
      pdf.paragraph('${ar ? 'كما في' : 'As of'}: ${_date(data.asOfDate)}'),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox(
        balanced
            ? (ar ? 'الميزان متوازن ✓' : 'The trial balance is balanced ✓')
            : (ar ? 'تحذير: الميزان غير متوازن' : 'Warning: the trial balance is NOT balanced'),
        tone: balanced ? 'green' : 'red',
      ),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
