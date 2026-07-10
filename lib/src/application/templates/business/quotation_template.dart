// APPLICATION · templates · business · sales quotation. Pure Dart.
//
// A price quotation with validity period and the same line/VAT/total shape as
// the tax invoice (quotations are not yet taxable supplies but customarily
// show the same breakdown so a customer can compare to the eventual invoice).

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// Data for a sales quotation.
class QuotationData {
  const QuotationData({
    required this.quotationNumber,
    required this.issueDate,
    required this.validUntil,
    required this.seller,
    required this.buyer,
    required this.lines,
    this.currency = 'SAR',
    this.terms,
    this.providedSubtotal,
    this.providedVatTotal,
    this.providedGrandTotal,
  });

  final String quotationNumber;
  final DateTime issueDate;
  final DateTime validUntil;
  final PdfParty seller;
  final PdfParty buyer;
  final List<PdfInvoiceLine> lines;
  final String currency;
  final String? terms;
  final double? providedSubtotal;
  final double? providedVatTotal;
  final double? providedGrandTotal;
}

class QuotationTemplate extends PdfTemplate<QuotationData> {
  const QuotationTemplate();

  @override
  String get id => 'quotation';
  @override
  String get name => 'Sales Quotation';
  @override
  String get nameAr => 'عرض سعر';
  @override
  String get description => 'Price quotation with validity period and totals.';

  @override
  GeniusFinancialValidationResult validate(QuotationData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    final results = <GeniusFinancialValidationResult>[];
    final nets = data.lines.map((l) => l.net).toList();
    final vats = data.lines.map((l) => l.vat).toList();
    if (data.providedSubtotal != null) {
      results.add(validator.validateSubtotal(lineTotals: nets, providedSubtotal: data.providedSubtotal!));
    }
    if (data.providedVatTotal != null) {
      results.add(validator.validateGridColumn(rowValues: vats, providedTotal: data.providedVatTotal!, columnId: 'vat_total'));
    }
    if (data.providedGrandTotal != null) {
      results.add(validator.validateGrandTotal(
        subtotal: nets.fold(0.0, (s, v) => s + v),
        discounts: 0,
        vatAmount: vats.fold(0.0, (s, v) => s + v),
        fees: 0,
        providedGrandTotal: data.providedGrandTotal!,
      ),);
    }
    return validator.combineResults(results);
  }

  @override
  PdfDocumentDefinition build(QuotationData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) => formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);

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
          fmt(l.vat),
          fmt(l.gross),
        ],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? 'عرض سعر' : 'Quotation'} ${data.quotationNumber}', author: data.seller.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'عرض سعر' : 'Sales Quotation'),
      pdf.row([
        pdf.column([
          pdf.heading(ar ? (data.seller.nameAr ?? data.seller.name) : data.seller.name, level: 2),
          if (data.seller.address != null) pdf.text(data.seller.address!),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم العرض' : 'Quotation #', data.quotationNumber),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.issueDate)),
            MapEntry(ar ? 'صالح حتى' : 'Valid Until', _date(data.validUntil)),
          ]),
        ]),
      ]),
      pdf.spacer(8),
      pdf.keyValue([
        MapEntry(ar ? 'مقدم إلى' : 'Prepared For', ar ? (data.buyer.nameAr ?? data.buyer.name) : data.buyer.name),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'الإجمالي الفرعي' : 'Subtotal', fmt(subtotal)),
        MapEntry(ar ? 'إجمالي الضريبة' : 'Total VAT', fmt(vatTotal)),
        MapEntry(ar ? 'الإجمالي الكلي' : 'Grand Total', fmt(grand)),
      ]),
      if (data.terms != null) ...[pdf.spacer(8), pdf.infoBox(data.terms!, tone: 'blue')],
      pdf.spacer(16),
      pdf.signatureBlock(name: data.seller.name, role: ar ? 'التوقيع' : 'Authorized Signature'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
