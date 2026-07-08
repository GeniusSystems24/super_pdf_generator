// APPLICATION · templates · business · sales documents. Pure Dart.
//
// Quotation, Purchase Order, Delivery Note and Credit Note. All four are
// itemized documents that share a common layout and financial validation
// (line subtotals → subtotal, and subtotal − discounts + tax = grand total),
// mirroring the GeniusLink PDF reference's sales template family.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// Common data for an itemized sales/purchase document.
class ItemizedDocumentData {
  const ItemizedDocumentData({
    required this.number,
    required this.date,
    required this.party,
    required this.items,
    this.secondDate,
    this.currency = 'SAR',
    this.status,
    this.statusAr,
    this.notes,
    this.terms,
    this.providedGrandTotal,
  });

  final String number;
  final DateTime date;

  /// Optional second date (valid-until / delivery / expected date).
  final DateTime? secondDate;
  final PdfParty party;
  final List<PdfLineItem> items;
  final String currency;
  final String? status;
  final String? statusAr;
  final String? notes;
  final String? terms;
  final double? providedGrandTotal;

  double get subtotal => items.fold(0.0, (s, i) => s + i.subtotal);
  double get totalDiscount => items.fold(0.0, (s, i) => s + i.discount);
  double get totalTax => items.fold(0.0, (s, i) => s + i.tax);
  double get grandTotal => subtotal - totalDiscount + totalTax;
}

/// Shared base that renders the itemized document; subclasses supply labels.
abstract class _ItemizedTemplate extends PdfTemplate<ItemizedDocumentData> {
  const _ItemizedTemplate();

  String get titleEn;
  String get titleAr;
  String get partyLabelEn;
  String get partyLabelAr;
  String get numberLabelEn => '$titleEn No.';
  String get numberLabelAr => 'رقم';
  String get secondDateLabelEn => 'Valid Until';
  String get secondDateLabelAr => 'صالح حتى';
  bool get showAmounts => true;
  bool get showSignatures => false;

  @override
  String get name => titleEn;
  @override
  String get nameAr => titleAr;

  @override
  GeniusFinancialValidationResult validate(ItemizedDocumentData data, {PdfTemplateContext? context}) {
    if (!showAmounts) return GeniusFinancialValidationResult.valid();
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    final results = <GeniusFinancialValidationResult>[
      if (data.providedGrandTotal != null)
        validator.validateGrandTotal(
          subtotal: data.subtotal,
          discounts: data.totalDiscount,
          vatAmount: data.totalTax,
          fees: 0,
          providedGrandTotal: data.providedGrandTotal!,
        ),
    ];
    return validator.combineResults(results);
  }

  @override
  PdfDocumentDefinition build(ItemizedDocumentData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

    final columns = ar
        ? ['#', 'الوصف', 'الكمية', if (showAmounts) ...['السعر', 'الإجمالي']]
        : ['#', 'Description', 'Qty', if (showAmounts) ...['Unit', 'Total']];
    final rows = <List<String>>[
      for (final it in data.items)
        [
          '${it.itemNumber}',
          ar ? (it.descriptionAr ?? it.description) : it.description,
          '${_num(it.quantity)}${it.unit != null ? ' ${it.unit}' : ''}',
          if (showAmounts) ...[fmt(it.unitPrice), fmt(it.total)],
        ],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? titleAr : titleEn} ${data.number}', author: data.party.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? titleAr : titleEn),
      pdf.row([
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? partyLabelAr : partyLabelEn, ar ? (data.party.nameAr ?? data.party.name) : data.party.name),
            if (data.party.taxNumber != null) MapEntry(ar ? 'الرقم الضريبي' : 'VAT No.', data.party.taxNumber!),
            if (data.party.address != null) MapEntry(ar ? 'العنوان' : 'Address', data.party.address!),
            if (data.party.phone != null) MapEntry(ar ? 'الهاتف' : 'Phone', data.party.phone!),
          ]),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? numberLabelAr : numberLabelEn, data.number),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.date)),
            if (data.secondDate != null) MapEntry(ar ? secondDateLabelAr : secondDateLabelEn, _date(data.secondDate!)),
            if (data.status != null) MapEntry(ar ? 'الحالة' : 'Status', ar ? (data.statusAr ?? data.status!) : data.status!),
            MapEntry(ar ? 'العملة' : 'Currency', data.currency),
          ]),
        ]),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      if (showAmounts) ...[
        pdf.spacer(10),
        pdf.row([
          pdf.column([pdf.qrCode('${titleEn.toUpperCase()}:${data.number}|TOT:${data.grandTotal.toStringAsFixed(cur.decimalPlaces)}')]),
          pdf.column([
            pdf.keyValue([
              MapEntry(ar ? 'المجموع الفرعي' : 'Subtotal', fmt(data.subtotal)),
              if (data.totalDiscount > 0) MapEntry(ar ? 'الخصم' : 'Discount', '-${fmt(data.totalDiscount)}'),
              if (data.totalTax > 0) MapEntry(ar ? 'الضريبة' : 'Tax (VAT)', fmt(data.totalTax)),
              MapEntry(ar ? 'الإجمالي النهائي' : 'Grand Total', fmt(data.grandTotal)),
            ]),
          ]),
        ]),
      ],
      if (data.notes != null) ...[pdf.spacer(8), pdf.infoBox('${ar ? 'ملاحظات' : 'Notes'}: ${data.notes}', tone: 'blue')],
      if (data.terms != null) ...[pdf.spacer(6), pdf.paragraph('${ar ? 'الشروط والأحكام' : 'Terms & Conditions'}: ${data.terms}')],
      if (showSignatures) ...[
        pdf.spacer(16),
        pdf.row([
          pdf.signatureBlock(name: '', role: ar ? 'التوقيع المعتمد' : 'Authorized Signature'),
          pdf.signatureBlock(name: '', role: ar ? 'المستلم' : 'Received By'),
        ]),
      ],
      pdf.spacer(10),
      pdf.footer(text: ar ? 'شكراً لتعاملكم معنا' : 'Thank you for your business'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A price quotation.
class QuotationTemplate extends _ItemizedTemplate {
  const QuotationTemplate();
  @override
  String get id => 'quotation';
  @override
  String get titleEn => 'Quotation';
  @override
  String get titleAr => 'عرض سعر';
  @override
  String get partyLabelEn => 'Customer';
  @override
  String get partyLabelAr => 'العميل';
  @override
  String get description => 'Price quotation with items, taxes and validity.';
  @override
  bool get showSignatures => true;
}

/// A purchase order.
class PurchaseOrderTemplate extends _ItemizedTemplate {
  const PurchaseOrderTemplate();
  @override
  String get id => 'purchase_order';
  @override
  String get titleEn => 'Purchase Order';
  @override
  String get titleAr => 'أمر شراء';
  @override
  String get partyLabelEn => 'Supplier';
  @override
  String get partyLabelAr => 'المورد';
  @override
  String get secondDateLabelEn => 'Expected Date';
  @override
  String get secondDateLabelAr => 'تاريخ التوريد المتوقع';
  @override
  String get description => 'Purchase order to a supplier with line items and totals.';
  @override
  bool get showSignatures => true;
}

/// A delivery note (quantities only; amounts hidden).
class DeliveryNoteTemplate extends _ItemizedTemplate {
  const DeliveryNoteTemplate();
  @override
  String get id => 'delivery_note';
  @override
  String get titleEn => 'Delivery Note';
  @override
  String get titleAr => 'إشعار تسليم';
  @override
  String get partyLabelEn => 'Deliver To';
  @override
  String get partyLabelAr => 'التسليم إلى';
  @override
  String get secondDateLabelEn => 'Delivery Date';
  @override
  String get secondDateLabelAr => 'تاريخ التسليم';
  @override
  String get description => 'Goods delivery note listing delivered quantities.';
  @override
  bool get showAmounts => false;
  @override
  bool get showSignatures => true;
}

/// A credit note (issued to a customer). `DebitNoteTemplate` is a supplier-side
/// alias with the same structure.
class CreditNoteTemplate extends _ItemizedTemplate {
  const CreditNoteTemplate();
  @override
  String get id => 'credit_note';
  @override
  String get titleEn => 'Credit Note';
  @override
  String get titleAr => 'إشعار دائن';
  @override
  String get partyLabelEn => 'Customer';
  @override
  String get partyLabelAr => 'العميل';
  @override
  String get secondDateLabelEn => 'Original Invoice';
  @override
  String get secondDateLabelAr => 'الفاتورة الأصلية';
  @override
  String get description => 'Credit note reversing charges on an invoice.';
}

/// Debit note — supplier-side alias of [CreditNoteTemplate].
class DebitNoteTemplate extends _ItemizedTemplate {
  const DebitNoteTemplate();
  @override
  String get id => 'debit_note';
  @override
  String get titleEn => 'Debit Note';
  @override
  String get titleAr => 'إشعار مدين';
  @override
  String get partyLabelEn => 'Supplier';
  @override
  String get partyLabelAr => 'المورد';
  @override
  String get description => 'Debit note increasing amounts due to/from a party.';
}
