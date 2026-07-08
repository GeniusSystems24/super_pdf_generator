// APPLICATION · templates · business · customer statement. Pure Dart.
//
// A customer account statement with aging summary and a validated closing
// balance. Mirrors the reference CustomerStatementTemplate.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// A single customer transaction. Debit increases what the customer owes;
/// credit (payment) reduces it.
class CustomerTransaction {
  const CustomerTransaction({
    required this.date,
    required this.description,
    this.reference,
    this.debit = 0,
    this.credit = 0,
    this.descriptionAr,
  });
  final DateTime date;
  final String description;
  final String? descriptionAr;
  final String? reference;
  final double debit;
  final double credit;
}

/// Optional aging bucket for the statement summary.
class AgingBucket {
  const AgingBucket({required this.label, required this.amount, this.labelAr});
  final String label;
  final String? labelAr;
  final double amount;
}

/// Data for a customer statement.
class CustomerStatementData {
  const CustomerStatementData({
    required this.customer,
    required this.accountNumber,
    required this.periodLabel,
    required this.openingBalance,
    required this.transactions,
    this.aging = const <AgingBucket>[],
    this.currency = 'SAR',
    this.providedClosingBalance,
  });

  final PdfParty customer;
  final String accountNumber;
  final String periodLabel;
  final double openingBalance;
  final List<CustomerTransaction> transactions;
  final List<AgingBucket> aging;
  final String currency;
  final double? providedClosingBalance;

  double get closingBalance =>
      openingBalance + transactions.fold(0.0, (s, t) => s + t.debit - t.credit);
}

class CustomerStatementTemplate extends PdfTemplate<CustomerStatementData> {
  const CustomerStatementTemplate();

  @override
  String get id => 'customer_statement';
  @override
  String get name => 'Customer Statement';
  @override
  String get nameAr => 'كشف حساب عميل';
  @override
  String get description => 'Customer account statement with aging + closing balance.';

  @override
  GeniusFinancialValidationResult validate(CustomerStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedClosingBalance == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGrandTotal(
      subtotal: data.openingBalance,
      discounts: data.transactions.fold(0.0, (s, t) => s + t.credit),
      vatAmount: data.transactions.fold(0.0, (s, t) => s + t.debit),
      fees: 0,
      providedGrandTotal: data.providedClosingBalance!,
    );
  }

  @override
  PdfDocumentDefinition build(CustomerStatementData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    var running = data.openingBalance;
    final rows = <List<String>>[];
    for (final t in data.transactions) {
      running += t.debit - t.credit;
      rows.add([
        _date(t.date),
        t.reference ?? '',
        ar ? (t.descriptionAr ?? t.description) : t.description,
        t.debit == 0 ? '—' : fmt(t.debit),
        t.credit == 0 ? '—' : fmt(t.credit),
        fmt(running),
      ]);
    }

    final columns = ar
        ? ['التاريخ', 'المرجع', 'البيان', 'مدين', 'دائن', 'الرصيد']
        : ['Date', 'Ref', 'Description', 'Debit', 'Credit', 'Balance'];

    return pdfDocument()
        .metadata(title: '${ar ? 'كشف حساب عميل' : 'Customer Statement'} — ${data.accountNumber}', author: data.customer.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'كشف حساب عميل' : 'Customer Statement'),
      pdf.keyValue([
        MapEntry(ar ? 'العميل' : 'Customer', ar ? (data.customer.nameAr ?? data.customer.name) : data.customer.name),
        MapEntry(ar ? 'رقم الحساب' : 'Account No.', data.accountNumber),
        MapEntry(ar ? 'الفترة' : 'Period', data.periodLabel),
        MapEntry(ar ? 'الرصيد الافتتاحي' : 'Opening Balance', fmt(data.openingBalance)),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.infoBox('${ar ? 'الرصيد الختامي' : 'Closing Balance'}: ${fmt(data.closingBalance)}', tone: 'blue'),
      if (data.aging.isNotEmpty) ...[
        pdf.spacer(10),
        pdf.heading(ar ? 'تحليل أعمار الديون' : 'Aging Analysis', level: 3),
        pdf.dataTable(
          columns: ar ? ['الفترة', 'المبلغ'] : ['Bucket', 'Amount'],
          rows: [for (final b in data.aging) [ar ? (b.labelAr ?? b.label) : b.label, fmt(b.amount)]],
        ),
      ],
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
