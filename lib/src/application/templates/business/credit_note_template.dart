// APPLICATION · templates · business · credit note. Pure Dart.
//
// A credit note against a prior invoice (returns / price corrections). Same
// VAT-aware line shape as the tax invoice but frames totals as a credit, and
// references the original invoice number.

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

/// Data for a credit note.
class CreditNoteData {
  const CreditNoteData({
    required this.creditNoteNumber,
    required this.issueDate,
    required this.originalInvoiceNumber,
    required this.seller,
    required this.buyer,
    required this.lines,
    required this.reason,
    this.currency = 'SAR',
    this.reasonAr,
    this.providedGrandTotal,
  });

  final String creditNoteNumber;
  final DateTime issueDate;
  final String originalInvoiceNumber;
  final PdfParty seller;
  final PdfParty buyer;
  final List<PdfInvoiceLine> lines;
  final String reason;
  final String? reasonAr;
  final String currency;
  final double? providedGrandTotal;
}

class CreditNoteTemplate extends PdfTemplate<CreditNoteData> {
  const CreditNoteTemplate();

  @override
  String get id => 'credit_note';
  @override
  String get name => 'Credit Note';
  @override
  String get nameAr => 'إشعار دائن';
  @override
  String get description => 'Credit note against a prior invoice, with reason and totals.';

  @override
  GeniusFinancialValidationResult validate(CreditNoteData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedGrandTotal == null) return GeniusFinancialValidationResult.valid();
    final nets = data.lines.map((l) => l.net).toList();
    final vats = data.lines.map((l) => l.vat).toList();
    return validator.validateGrandTotal(
      subtotal: nets.fold(0.0, (s, v) => s + v),
      discounts: 0,
      vatAmount: vats.fold(0.0, (s, v) => s + v),
      fees: 0,
      providedGrandTotal: data.providedGrandTotal!,
    );
  }

  @override
  PdfDocumentDefinition build(CreditNoteData data, {PdfTemplateContext? context}) {
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

    final words = amountInWords(grand,
        currencyCode: data.currency,
        language: ar ? AmountWordsLanguage.arabic : AmountWordsLanguage.english,
        fractionDigits: cur.decimalPlaces,);

    return pdfDocument()
        .metadata(title: '${ar ? 'إشعار دائن' : 'Credit Note'} ${data.creditNoteNumber}', author: data.seller.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'إشعار دائن' : 'Credit Note'),
      pdf.row([
        pdf.column([
          pdf.heading(ar ? (data.seller.nameAr ?? data.seller.name) : data.seller.name, level: 2),
          if (data.seller.taxNumber != null) pdf.text('${ar ? 'الرقم الضريبي' : 'VAT No.'}: ${data.seller.taxNumber}'),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم الإشعار' : 'Credit Note #', data.creditNoteNumber),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.issueDate)),
            MapEntry(ar ? 'الفاتورة الأصلية' : 'Original Invoice', data.originalInvoiceNumber),
          ]),
        ]),
      ]),
      pdf.spacer(8),
      pdf.keyValue([
        MapEntry(ar ? 'العميل' : 'Customer', ar ? (data.buyer.nameAr ?? data.buyer.name) : data.buyer.name),
      ]),
      pdf.spacer(6),
      pdf.infoBox('${ar ? 'السبب' : 'Reason'}: ${ar ? (data.reasonAr ?? data.reason) : data.reason}', tone: 'orange'),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'الإجمالي الفرعي' : 'Subtotal', fmt(subtotal)),
        MapEntry(ar ? 'إجمالي الضريبة' : 'Total VAT', fmt(vatTotal)),
        MapEntry(ar ? 'إجمالي المبلغ الدائن' : 'Total Credit', fmt(grand)),
      ]),
      pdf.spacer(6),
      pdf.paragraph('${ar ? 'المبلغ كتابةً' : 'Amount in words'}: $words'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
