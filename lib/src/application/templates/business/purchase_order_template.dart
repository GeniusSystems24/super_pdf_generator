// APPLICATION · templates · business · purchase order. Pure Dart.
//
// A purchase order to a supplier: line items, delivery terms, and a validated
// grand total.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';
import 'models.dart';

/// A single purchase-order line (no per-line VAT split; PO totals are usually
/// pre-tax with a single VAT line).
class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.descriptionAr,
    this.unit = 'pc',
  });
  final String description;
  final String? descriptionAr;
  final double quantity;
  final double unitPrice;
  final String unit;

  double get total => quantity * unitPrice;
}

/// Data for a purchase order.
class PurchaseOrderData {
  const PurchaseOrderData({
    required this.poNumber,
    required this.issueDate,
    required this.buyer,
    required this.supplier,
    required this.lines,
    this.currency = 'SAR',
    this.vatRate = 15,
    this.deliveryDate,
    this.deliveryAddress,
    this.providedGrandTotal,
  });

  final String poNumber;
  final DateTime issueDate;
  final DateTime? deliveryDate;
  final String? deliveryAddress;
  final PdfParty buyer;
  final PdfParty supplier;
  final List<PurchaseOrderLine> lines;
  final String currency;
  final double vatRate;
  final double? providedGrandTotal;

  double get subtotal => lines.fold(0.0, (s, l) => s + l.total);
  double get vatAmount => subtotal * vatRate / 100;
  double get grandTotal => subtotal + vatAmount;
}

class PurchaseOrderTemplate extends PdfTemplate<PurchaseOrderData> {
  const PurchaseOrderTemplate();

  @override
  String get id => 'purchase_order';
  @override
  String get name => 'Purchase Order';
  @override
  String get nameAr => 'أمر شراء';
  @override
  String get description => 'Purchase order to a supplier with delivery terms.';

  @override
  GeniusFinancialValidationResult validate(PurchaseOrderData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedGrandTotal == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGrandTotal(
      subtotal: data.subtotal,
      discounts: 0,
      vatAmount: data.vatAmount,
      fees: 0,
      providedGrandTotal: data.providedGrandTotal!,
    );
  }

  @override
  PdfDocumentDefinition build(PurchaseOrderData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) => formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);
    String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

    final columns = ar
        ? ['#', 'البيان', 'الوحدة', 'الكمية', 'السعر', 'الإجمالي']
        : ['#', 'Description', 'Unit', 'Qty', 'Price', 'Total'];
    final rows = <List<String>>[
      for (final (i, l) in data.lines.indexed)
        ['${i + 1}', ar ? (l.descriptionAr ?? l.description) : l.description, l.unit, num(l.quantity), fmt(l.unitPrice), fmt(l.total)],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? 'أمر شراء' : 'Purchase Order'} ${data.poNumber}', author: data.buyer.name)
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, marginsAll: 36)
        .content([
      pdf.header(title: ar ? 'أمر شراء' : 'Purchase Order'),
      pdf.row([
        pdf.column([
          pdf.heading(ar ? (data.buyer.nameAr ?? data.buyer.name) : data.buyer.name, level: 2),
          if (data.buyer.address != null) pdf.text(data.buyer.address!),
        ]),
        pdf.column([
          pdf.keyValue([
            MapEntry(ar ? 'رقم الأمر' : 'PO #', data.poNumber),
            MapEntry(ar ? 'التاريخ' : 'Date', _date(data.issueDate)),
            if (data.deliveryDate != null) MapEntry(ar ? 'تاريخ التسليم' : 'Delivery Date', _date(data.deliveryDate!)),
          ]),
        ]),
      ]),
      pdf.spacer(8),
      pdf.keyValue([
        MapEntry(ar ? 'المورد' : 'Supplier', ar ? (data.supplier.nameAr ?? data.supplier.name) : data.supplier.name),
        if (data.deliveryAddress != null) MapEntry(ar ? 'عنوان التسليم' : 'Deliver To', data.deliveryAddress!),
      ]),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.keyValue([
        MapEntry(ar ? 'الإجمالي الفرعي' : 'Subtotal', fmt(data.subtotal)),
        MapEntry(ar ? 'ضريبة القيمة المضافة (${data.vatRate.toStringAsFixed(0)}%)' : 'VAT (${data.vatRate.toStringAsFixed(0)}%)', fmt(data.vatAmount)),
        MapEntry(ar ? 'الإجمالي الكلي' : 'Grand Total', fmt(data.grandTotal)),
      ]),
      pdf.spacer(16),
      pdf.signatureBlock(name: data.buyer.name, role: ar ? 'أمر معتمد من' : 'Authorized By'),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
