// APPLICATION · templates · business · inventory report. Pure Dart.
//
// Stock-on-hand valuation: quantity × unit cost = line value, with a validated
// total valuation and a low-stock highlight.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_financial_validator.dart';
import '../../../domain/financial/genius_money.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/value_objects.dart';
import '../../builder.dart';
import '../engine/template.dart';
import '../support/money_format.dart';

/// A single inventory item.
class InventoryItem {
  const InventoryItem({
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.nameAr,
    this.reorderLevel,
    this.location,
  });
  final String sku;
  final String name;
  final String? nameAr;
  final double quantity;
  final double unitCost;
  final double? reorderLevel;
  final String? location;

  double get value => quantity * unitCost;
  bool get isLow => reorderLevel != null && quantity <= reorderLevel!;
}

/// Data for an inventory report.
class InventoryReportData {
  const InventoryReportData({
    required this.reportDate,
    required this.items,
    this.warehouseName,
    this.warehouseNameAr,
    this.currency = 'SAR',
    this.providedTotalValue,
  });

  final DateTime reportDate;
  final List<InventoryItem> items;
  final String? warehouseName;
  final String? warehouseNameAr;
  final String currency;
  final double? providedTotalValue;

  double get totalValue => items.fold(0.0, (s, i) => s + i.value);
  int get lowStockCount => items.where((i) => i.isLow).length;
}

class InventoryReportTemplate extends PdfTemplate<InventoryReportData> {
  const InventoryReportTemplate();

  @override
  String get id => 'inventory_report';
  @override
  String get name => 'Inventory Report';
  @override
  String get nameAr => 'تقرير المخزون';
  @override
  String get description => 'Stock valuation with low-stock highlighting.';

  @override
  GeniusFinancialValidationResult validate(InventoryReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validator = GeniusFinancialValidator(ctx.roundingPolicy);
    if (data.providedTotalValue == null) return GeniusFinancialValidationResult.valid();
    return validator.validateGridColumn(
      rowValues: data.items.map((i) => i.value).toList(),
      providedTotal: data.providedTotalValue!,
      columnId: 'total_value',
    );
  }

  @override
  PdfDocumentDefinition build(InventoryReportData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final ar = ctx.isArabic;
    final policy = ctx.roundingPolicy;
    final cur = CurrencyFormat.forCode(data.currency);
    String fmt(double v) =>
        formatMoney(GeniusMoney.fromDouble(v, currency: data.currency, policy: policy), format: cur);
    String num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

    final columns = ar
        ? ['الرمز', 'الصنف', 'الموقع', 'الكمية', 'التكلفة', 'القيمة']
        : ['SKU', 'Item', 'Location', 'Qty', 'Unit Cost', 'Value'];
    final rows = <List<String>>[
      for (final i in data.items)
        [
          i.sku,
          '${ar ? (i.nameAr ?? i.name) : i.name}${i.isLow ? (ar ? ' ⚠ منخفض' : ' ⚠ LOW') : ''}',
          i.location ?? '—',
          num(i.quantity),
          fmt(i.unitCost),
          fmt(i.value),
        ],
      ['', ar ? 'إجمالي القيمة' : 'TOTAL VALUE', '', '', '', fmt(data.totalValue)],
    ];

    return pdfDocument()
        .metadata(title: '${ar ? 'تقرير المخزون' : 'Inventory Report'} — ${_date(data.reportDate)}', author: data.warehouseName ?? '')
        .direction(ctx.direction)
        .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.landscape, marginsAll: 32)
        .content([
      pdf.header(title: ar ? 'تقرير المخزون' : 'Inventory Valuation Report'),
      if (data.warehouseName != null)
        pdf.heading(ar ? (data.warehouseNameAr ?? data.warehouseName!) : data.warehouseName!, level: 2),
      pdf.paragraph('${ar ? 'كما في' : 'As of'}: ${_date(data.reportDate)}'),
      pdf.spacer(12),
      pdf.dataTable(columns: columns, rows: rows, zebra: true),
      pdf.spacer(10),
      pdf.row([
        pdf.column([pdf.keyValue([MapEntry(ar ? 'عدد الأصناف' : 'Item Count', '${data.items.length}')])]),
        pdf.column([
          pdf.infoBox(
            data.lowStockCount == 0
                ? (ar ? 'لا توجد أصناف منخفضة' : 'No low-stock items')
                : (ar ? '${data.lowStockCount} صنف بحاجة لإعادة طلب' : '${data.lowStockCount} item(s) need reorder'),
            tone: data.lowStockCount == 0 ? 'green' : 'orange',
          ),
        ]),
      ]),
      pdf.pageNumber(),
    ]).build();
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
