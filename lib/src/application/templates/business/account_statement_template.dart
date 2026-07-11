// APPLICATION · templates · business · account statement. Pure Dart.
//
// A running-balance account statement. Recomputes the running balance from the
// opening balance and validates the closing balance.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// A single statement transaction. Positive [debit] reduces the balance;
/// positive [credit] increases it.
class StatementEntry {
  const StatementEntry({
    required this.date,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    this.reference,
    this.descriptionAr,
  });
  final DateTime date;
  final String description;
  final String? descriptionAr;
  final double debit;
  final double credit;
  final String? reference;
}

/// Data for an account statement.
class AccountStatementData {
  const AccountStatementData({
    required this.holder,
    required this.accountNumber,
    required this.periodLabel,
    required this.openingBalance,
    required this.entries,
    this.currency = 'SAR',
    this.providedClosingBalance,
  });
  final PdfParty holder;
  final String accountNumber;
  final String periodLabel;
  final double openingBalance;
  final List<StatementEntry> entries;
  final String currency;
  final double? providedClosingBalance;
}

class AccountStatementTemplate extends PdfTemplate<AccountStatementData> {
  const AccountStatementTemplate();

  @override
  String get id => 'account_statement';
  @override
  String get name => 'Account Statement';
  @override
  String get nameAr => 'كشف حساب';
  @override
  String get description => 'Running-balance statement with validated closing balance.';


  @override
  GeniusFinancialValidationResult validate(AccountStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedClosingBalance == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGrandTotal(
      subtotal: data.openingBalance,
      discounts: data.entries.fold(0.0, (s, e) => s + e.debit),
      vatAmount: data.entries.fold(0.0, (s, e) => s + e.credit),
      fees: 0,
      providedGrandTotal: data.providedClosingBalance!,
    );
  }

  @override
  PdfDocumentDefinition build(AccountStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    var running = data.openingBalance;
    final rows = <List<String>>[];
    for (final e in data.entries) {
      running += e.credit - e.debit;
      rows.add([
        _date(e.date),
        ar ? (e.descriptionAr ?? e.description) : e.description,
        e.debit == 0 ? '—' : fmt(e.debit),
        e.credit == 0 ? '—' : fmt(e.credit),
        fmt(running),
      ]);
    }
    final closing = policy.round(running);

    final columns = ar
        ? ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد']
        : ['Date', 'Description', 'Debit', 'Credit', 'Balance'];

    return pdfDocument()
        .metadata(title: '${ar ? 'كشف حساب' : 'Account Statement'} — ${data.accountNumber}', author: data.holder.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'كشف حساب' : 'Account Statement'),
      pdf.keyValue([
        MapEntry(ar ? 'صاحب الحساب' : 'Account Holder', ar ? (data.holder.nameAr ?? data.holder.name) : data.holder.name),
        MapEntry(ar ? 'رقم الحساب' : 'Account No.', data.accountNumber),
        MapEntry(ar ? 'الفترة' : 'Period', data.periodLabel),
        MapEntry(ar ? 'الرصيد الافتتاحي' : 'Opening Balance', fmt(data.openingBalance)),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox('${ar ? 'الرصيد الختامي' : 'Closing Balance'}: ${fmt(closing)}', tone: 'blue'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
