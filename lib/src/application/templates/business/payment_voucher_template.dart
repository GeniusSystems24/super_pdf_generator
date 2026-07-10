// APPLICATION · templates · business · payment voucher. Pure Dart.
//
// A payment/receipt voucher with the amount printed both numerically and in
// words, and a validated net (amount − fee − commission) when provided.

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

/// Voucher kind.
enum VoucherKind { payment, receipt }

/// Data for a payment/receipt voucher.
class PaymentVoucherData {
  const PaymentVoucherData({
    required this.voucherNumber,
    required this.date,
    required this.payer,
    required this.payee,
    required this.amount,
    required this.purpose,
    this.kind = VoucherKind.payment,
    this.currency = 'SAR',
    this.fee = 0,
    this.commission = 0,
    this.providedNet,
    this.method,
    this.purposeAr,
  });

  final String voucherNumber;
  final DateTime date;
  final PdfParty payer;
  final PdfParty payee;
  final double amount;
  final String purpose;
  final String? purposeAr;
  final VoucherKind kind;
  final String currency;
  final double fee;
  final double commission;
  final double? providedNet;
  final String? method;
}

class PaymentVoucherTemplate extends PdfTemplate<PaymentVoucherData> {
  const PaymentVoucherTemplate();

  @override
  String get id => 'payment_voucher';
  @override
  String get name => 'Payment Voucher';
  @override
  String get nameAr => 'سند صرف';
  @override
  String get description => 'Payment/receipt voucher with amount in words.';

  @override
  GeniusFinancialValidationResult validate(PaymentVoucherData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedNet == null) return GeniusFinancialValidationResult.valid();
    return validator.validateTransferNet(
      sourceAmount: data.amount,
      fee: data.fee,
      commission: data.commission,
      providedNetAmount: data.providedNet!,
    );
  }

  @override
  PdfDocumentDefinition build(PaymentVoucherData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final net = policy.round(data.amount - data.fee - data.commission);
    final isPayment = data.kind == VoucherKind.payment;
    final titleEn = isPayment ? 'Payment Voucher' : 'Receipt Voucher';
    final titleAr = isPayment ? 'سند صرف' : 'سند قبض';

    final words = amountInWords(net,
        currencyCode: data.currency,
        language: ar ? AmountWordsLanguage.arabic : AmountWordsLanguage.english,
        fractionDigits: cur.decimalPlaces,);

    return pdfDocument()
        .metadata(title: '${ar ? titleAr : titleEn} ${data.voucherNumber}', author: data.payer.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a5, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? titleAr : titleEn),
      pdf.row([
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم السند' : 'Voucher #', data.voucherNumber),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.date)),
            if (data.method != null) MapEntry(ar ? 'طريقة الدفع' : 'Method', data.method!),
          ]),
        ]),
        pdf.column([
          pdf.statusBadge(label: (ar ? titleAr : titleEn).toUpperCase(), tone: isPayment ? 'orange' : 'green'),
        ]),
      ]),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(isPayment ? (ar ? 'المدفوع له' : 'Pay To') : (ar ? 'المستلم من' : 'Received From'),
            ar ? (data.payee.nameAr ?? data.payee.name) : data.payee.name,),
        MapEntry(ar ? 'المبلغ' : 'Amount', fmt(data.amount)),
        if (data.fee != 0) MapEntry(ar ? 'الرسوم' : 'Fee', fmt(data.fee)),
        if (data.commission != 0) MapEntry(ar ? 'العمولة' : 'Commission', fmt(data.commission)),
        MapEntry(ar ? 'الصافي' : 'Net', fmt(net)),
      ]),
      pdf.spacer(8),
      pdf.infoBox('${ar ? 'المبلغ كتابةً' : 'Amount in words'}: $words', tone: 'blue'),
      pdf.spacer(6),
      pdf.paragraph('${ar ? 'وذلك عن' : 'Being'}: ${ar ? (data.purposeAr ?? data.purpose) : data.purpose}'),
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
