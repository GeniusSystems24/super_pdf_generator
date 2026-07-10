// APPLICATION · templates · business · tax invoice. Pure Dart.
//
// A VAT (ZATCA-style) tax invoice. Recomputes every total with GeniusMoney and
// validates the caller-provided figures with GeniusFinancialValidator, so a
// document only renders when its arithmetic is provably correct.

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

/// Data for a tax invoice.
class TaxInvoiceData {
  const TaxInvoiceData({
    required this.invoiceNumber,
    required this.issueDate,
    required this.seller,
    required this.buyer,
    required this.lines,
    this.currency = 'SAR',
    this.supplyDate,
    this.notes,
    this.qrPayload,
    this.providedSubtotal,
    this.providedVatTotal,
    this.providedGrandTotal,
  });

  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime? supplyDate;
  final PdfParty seller;
  final PdfParty buyer;
  final List<PdfInvoiceLine> lines;
  final String currency;
  final String? notes;

  /// Optional QR payload (e.g. ZATCA base64 TLV). When null, a QR is still
  /// drawn from a compact summary string.
  final String? qrPayload;

  /// Optional caller-provided totals; when supplied they are validated against
  /// the recomputed values.
  final double? providedSubtotal;
  final double? providedVatTotal;
  final double? providedGrandTotal;
}

class TaxInvoiceTemplate extends PdfTemplate<TaxInvoiceData> {
  const TaxInvoiceTemplate();

  @override
  String get id => 'tax_invoice';
  @override
  String get name => 'Tax Invoice';
  @override
  String get nameAr => 'فاتورة ضريبية';
  @override
  String get description => 'VAT tax invoice with line items, totals and QR.';

  @override
  GeniusFinancialValidationResult validate(TaxInvoiceData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    final results = <GeniusFinancialValidationResult>[];

    final nets = data.lines.map((l) => l.net).toList();
    final vats = data.lines.map((l) => l.vat).toList();
    final subtotal = nets.fold(0.0, (s, v) => s + v);
    final vatTotal = vats.fold(0.0, (s, v) => s + v);

    if (data.providedSubtotal != null) {
      results.add(validator.validateSubtotal(
        lineTotals: nets,
        providedSubtotal: data.providedSubtotal!,
      ),);
    }
    if (data.providedVatTotal != null) {
      results.add(validator.validateGridColumn(
        rowValues: vats,
        providedTotal: data.providedVatTotal!,
        columnId: 'vat_total',
      ),);
    }
    if (data.providedGrandTotal != null) {
      results.add(validator.validateGrandTotal(
        subtotal: subtotal,
        discounts: 0,
        vatAmount: vatTotal,
        fees: 0,
        providedGrandTotal: data.providedGrandTotal!,
      ),);
    }
    return validator.combineResults(results);
  }

  @override
  PdfDocumentDefinition build(TaxInvoiceData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);

    GeniusMoney money(double v) => GeniusMoney.fromDouble(v, currency: data.currency, policy: policy);
    String fmt(double v) => formatMoney(money(v), format: cur);

    final nets = data.lines.map((l) => l.net).toList();
    final vats = data.lines.map((l) => l.vat).toList();
    final subtotal = nets.fold(0.0, (s, v) => s + v);
    final vatTotal = vats.fold(0.0, (s, v) => s + v);
    final grand = policy.round(subtotal + vatTotal);

    final columns = ar
        ? ['#', 'البيان', 'الكمية', 'السعر', 'الصافي', 'الضريبة', 'الإجمالي']
        : ['#', 'Description', 'Qty', 'Unit', 'Net', 'VAT', 'Total'];

    final rows = <List<String>>[
      for (final (i, l) in data.lines.indexed)
        [
          '${i + 1}',
          ar ? (l.descriptionAr ?? l.description) : l.description,
          _num(l.quantity),
          fmt(l.unitPrice),
          fmt(l.net),
          '${fmt(l.vat)} (${_num(l.vatRate)}%)',
          fmt(l.gross),
        ],
    ];

    final words = amountInWords(
      grand,
      currencyCode: data.currency,
      language: ar ? AmountWordsLanguage.arabic : AmountWordsLanguage.english,
      fractionDigits: cur.decimalPlaces,
    );

    final builder = pdfDocument()
        .metadata(
          title: '${ar ? 'فاتورة ضريبية' : 'Tax Invoice'} ${data.invoiceNumber}',
          author: data.seller.name,
          subject: 'Tax Invoice',
        )
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'فاتورة ضريبية' : 'Tax Invoice'),
      pdf.row([
        pdf.column([
          pdf.heading(ar ? (data.seller.nameAr ?? data.seller.name) : data.seller.name, level: 2),
          if (data.seller.taxNumber != null)
            pdf.text('${ar ? 'الرقم الضريبي' : 'VAT No.'}: ${data.seller.taxNumber}'),
          if (data.seller.address != null) pdf.text(data.seller.address!),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم الفاتورة' : 'Invoice #', data.invoiceNumber),
            MapEntry(ar ? 'التاريخ' : 'Issue Date', _date(data.issueDate)),
            if (data.supplyDate != null)
              MapEntry(ar ? 'تاريخ التوريد' : 'Supply Date', _date(data.supplyDate!)),
          ]),
        ]),
      ]),
      pdf.spacer(8),
      pdf.keyValue([
        MapEntry(ar ? 'العميل' : 'Bill To', ar ? (data.buyer.nameAr ?? data.buyer.name) : data.buyer.name),
        if (data.buyer.taxNumber != null)
          MapEntry(ar ? 'الرقم الضريبي للعميل' : 'Buyer VAT No.', data.buyer.taxNumber!),
        if (data.buyer.address != null) MapEntry(ar ? 'العنوان' : 'Address', data.buyer.address!),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.row([
        pdf.column([
          pdf.qrCode(data.qrPayload ??
              'INV:${data.invoiceNumber}|TOT:${grand.toStringAsFixed(cur.decimalPlaces)}|VAT:${vatTotal.toStringAsFixed(cur.decimalPlaces)}',),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'الإجمالي الفرعي' : 'Subtotal', fmt(subtotal)),
            MapEntry(ar ? 'إجمالي الضريبة' : 'Total VAT', fmt(vatTotal)),
            MapEntry(ar ? 'الإجمالي الكلي' : 'Grand Total', fmt(grand)),
          ]),
        ]),
      ]),
      pdf.spacer(6),
      pdf.infoBox('${ar ? 'المبلغ كتابةً' : 'Amount in words'}: $words', tone: 'blue'),
      if (data.notes != null) ...[
        pdf.spacer(8),
        pdf.paragraph(data.notes!),
      ],
      pdf.spacer(12),
      pdf.footer(text: ar ? 'شكراً لتعاملكم معنا' : 'Thank you for your business'),
      pdf.pageNumber(),
    ]);

    return builder.build();
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
