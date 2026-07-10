// APPLICATION · templates · business · voucher family. Pure Dart.
//
// The source ships a broad family of voucher subtypes (expense, petty cash,
// journal, contra, bank/cash payment & receipt, salary, advance, refund,
// deposit …). They share one layout and one validation rule, so they are
// expressed as thin subclasses of [VoucherTemplateBase] — each contributing
// only its id, bilingual name, tone and money-direction. This keeps the
// "class per template" ergonomics without duplicating the build.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/amount_in_words.dart';
import '../support/money_format.dart';
import 'payment_voucher_template.dart';

/// Shared implementation for the voucher family. Subclasses provide identity
/// ([id], [name], [nameAr]), a [tone] and whether money is [isInbound]
/// (received) or outbound (paid). Reuses [PaymentVoucherData] as its model.
abstract class VoucherTemplateBase extends PdfTemplate<PaymentVoucherData> {
  const VoucherTemplateBase();

  /// Badge/accent tone: 'green' | 'orange' | 'blue' | 'red'.
  String get tone;

  /// True when the voucher records money *received*, false when *paid*.
  bool get isInbound;

  @override
  GeniusFinancialValidationResult validate(
    PaymentVoucherData data, {
    PdfTemplateContext? context,
  }) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedNet == null) {
      return GeniusFinancialValidationResult.valid();
    }
    return validator.validateTransferNet(
      sourceAmount: data.amount,
      fee: data.fee,
      commission: data.commission,
      providedNetAmount: data.providedNet!,
    );
  }

  @override
  PdfDocumentDefinition build(
    PaymentVoucherData data, {
    PdfTemplateContext? context,
  }) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) => formatMoney(
          GeniusMoney.fromDouble(v, currency: data.currency, policy: policy),
          format: cur,
        );

    final net = policy.round(data.amount - data.fee - data.commission);
    final title = ar ? nameAr : name;
    final counterparty = isInbound
        ? (ar ? 'المستلم من' : 'Received From')
        : (ar ? 'المدفوع له' : 'Pay To');

    final words = amountInWords(
      net,
      currencyCode: data.currency,
      language: ar ? AmountWordsLanguage.arabic : AmountWordsLanguage.english,
      fractionDigits: cur.decimalPlaces,
    );

    return pdfDocument()
        .metadata(title: '$title ${data.voucherNumber}', author: data.payer.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a5, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: title),
      pdf.row([
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم السند' : 'Voucher #', data.voucherNumber),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.date)),
            if (data.method != null)
              MapEntry(ar ? 'طريقة الدفع' : 'Method', data.method!),
          ]),
        ]),
        pdf.column([
          pdf.statusBadge(label: title.toUpperCase(), tone: tone),
        ]),
      ]),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(counterparty,
            ar ? (data.payee.nameAr ?? data.payee.name) : data.payee.name,),
        MapEntry(ar ? 'المبلغ' : 'Amount', fmt(data.amount)),
        if (data.fee != 0) MapEntry(ar ? 'الرسوم' : 'Fee', fmt(data.fee)),
        if (data.commission != 0)
          MapEntry(ar ? 'العمولة' : 'Commission', fmt(data.commission)),
        MapEntry(ar ? 'الصافي' : 'Net', fmt(net)),
      ]),
      pdf.spacer(8),
      pdf.infoBox('${ar ? 'المبلغ كتابةً' : 'Amount in words'}: $words', tone: 'blue'),
      pdf.spacer(6),
      pdf.paragraph(
          '${ar ? 'وذلك عن' : 'Being'}: ${ar ? (data.purposeAr ?? data.purpose) : data.purpose}',),
      pdf.spacer(16),
      pdf.row([
        pdf.signatureBlock(name: data.payer.name, role: ar ? 'المُصدِر' : 'Issued By'),
        pdf.signatureBlock(name: data.payee.name, role: ar ? 'المستلم' : 'Received By'),
      ]),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Expense disbursement voucher.
class ExpenseVoucherTemplate extends VoucherTemplateBase {
  const ExpenseVoucherTemplate();
  @override
  String get id => 'expense_voucher';
  @override
  String get name => 'Expense Voucher';
  @override
  String get nameAr => 'سند مصروفات';
  @override
  String get description => 'Records a general expense disbursement.';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Petty-cash disbursement voucher.
class PettyCashVoucherTemplate extends VoucherTemplateBase {
  const PettyCashVoucherTemplate();
  @override
  String get id => 'petty_cash_voucher';
  @override
  String get name => 'Petty Cash Voucher';
  @override
  String get nameAr => 'سند نثرية';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Journal (non-cash) voucher.
class JournalVoucherTemplate extends VoucherTemplateBase {
  const JournalVoucherTemplate();
  @override
  String get id => 'journal_voucher';
  @override
  String get name => 'Journal Voucher';
  @override
  String get nameAr => 'سند قيد';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'blue';
}

/// Contra voucher (transfer between two cash/bank accounts).
class ContraVoucherTemplate extends VoucherTemplateBase {
  const ContraVoucherTemplate();
  @override
  String get id => 'contra_voucher';
  @override
  String get name => 'Contra Voucher';
  @override
  String get nameAr => 'سند مناقلة';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'blue';
}

/// Bank payment voucher.
class BankPaymentVoucherTemplate extends VoucherTemplateBase {
  const BankPaymentVoucherTemplate();
  @override
  String get id => 'bank_payment_voucher';
  @override
  String get name => 'Bank Payment Voucher';
  @override
  String get nameAr => 'سند صرف بنكي';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Bank receipt voucher.
class BankReceiptVoucherTemplate extends VoucherTemplateBase {
  const BankReceiptVoucherTemplate();
  @override
  String get id => 'bank_receipt_voucher';
  @override
  String get name => 'Bank Receipt Voucher';
  @override
  String get nameAr => 'سند قبض بنكي';
  @override
  bool get isInbound => true;
  @override
  String get tone => 'green';
}

/// Cash payment voucher.
class CashPaymentVoucherTemplate extends VoucherTemplateBase {
  const CashPaymentVoucherTemplate();
  @override
  String get id => 'cash_payment_voucher';
  @override
  String get name => 'Cash Payment Voucher';
  @override
  String get nameAr => 'سند صرف نقدي';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Cash receipt voucher.
class CashReceiptVoucherTemplate extends VoucherTemplateBase {
  const CashReceiptVoucherTemplate();
  @override
  String get id => 'cash_receipt_voucher';
  @override
  String get name => 'Cash Receipt Voucher';
  @override
  String get nameAr => 'سند قبض نقدي';
  @override
  bool get isInbound => true;
  @override
  String get tone => 'green';
}

/// Salary disbursement voucher.
class SalaryVoucherTemplate extends VoucherTemplateBase {
  const SalaryVoucherTemplate();
  @override
  String get id => 'salary_voucher';
  @override
  String get name => 'Salary Voucher';
  @override
  String get nameAr => 'سند راتب';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Employee advance voucher.
class AdvanceVoucherTemplate extends VoucherTemplateBase {
  const AdvanceVoucherTemplate();
  @override
  String get id => 'advance_voucher';
  @override
  String get name => 'Advance Voucher';
  @override
  String get nameAr => 'سند سلفة';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'orange';
}

/// Customer/vendor refund voucher.
class RefundVoucherTemplate extends VoucherTemplateBase {
  const RefundVoucherTemplate();
  @override
  String get id => 'refund_voucher';
  @override
  String get name => 'Refund Voucher';
  @override
  String get nameAr => 'سند استرداد';
  @override
  bool get isInbound => false;
  @override
  String get tone => 'red';
}

/// Deposit receipt voucher.
class DepositVoucherTemplate extends VoucherTemplateBase {
  const DepositVoucherTemplate();
  @override
  String get id => 'deposit_voucher';
  @override
  String get name => 'Deposit Voucher';
  @override
  String get nameAr => 'سند إيداع';
  @override
  bool get isInbound => true;
  @override
  String get tone => 'green';
}
