import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../components/company_header.dart';
import '../components/document_title.dart';
import '../components/page_footer.dart';
import '../components/report_data_table.dart';
import '../core/report_direction.dart';
import '../core/report_formatting.dart';
import '../core/report_models.dart';
import '../theme/report_theme.dart';
import 'report_document.dart';

/// One stock line in an inventory valuation report.
class InventoryItem {
  const InventoryItem({
    required this.code,
    required this.name,
    required this.warehouse,
    required this.quantity,
    required this.avgCost,
    this.nameAr,
    this.warehouseAr,
    double? totalValue,
  }) : _total = totalValue;

  final String code;
  final String name;
  final String? nameAr;
  final String warehouse;
  final String? warehouseAr;
  final double quantity;
  final double avgCost;
  final double? _total;

  double get totalValue => _total ?? quantity * avgCost;
  String nameFor(ReportDir dir) => dir.isRtl ? (nameAr ?? name) : name;
  String warehouseFor(ReportDir dir) => dir.isRtl ? (warehouseAr ?? warehouse) : warehouse;
}

/// A product category with a computed value subtotal.
class InventoryCategory {
  const InventoryCategory(this.title, this.items, {this.titleAr});
  final String title;
  final String? titleAr;
  final List<InventoryItem> items;

  double get totalValue => items.fold(0.0, (s, i) => s + i.totalValue);
  String titleFor(ReportDir dir) => dir.isRtl ? (titleAr ?? title) : title;
}

/// Data for an inventory valuation report matching the GeniusLink reference.
class InventoryReportData {
  const InventoryReportData({
    required this.company,
    required this.asOf,
    required this.categories,
    this.user,
    this.currency = 'SAR',
    this.printedAt,
  });

  final ReportCompany company;
  final DateTime asOf;
  final List<InventoryCategory> categories;
  final String? user;
  final String currency;
  final DateTime? printedAt;

  double get grandTotal => categories.fold(0.0, (s, c) => s + c.totalValue);
}

/// Builds the inventory-valuation PDF (LTR or RTL) from [InventoryReportData].
class InventoryValuationReport {
  const InventoryValuationReport(this.data, {this.dir = ReportDir.ltr});

  final InventoryReportData data;
  final ReportDir dir;

  Future<Uint8List> build(ReportTheme baseTheme) {
    final theme = baseTheme.withDir(dir);
    final fmt = ReportFormat(currencyCode: data.currency);
    String n(double v) => fmt.number(v);

    final columns = <ReportColumn>[
      const ReportColumn(title: 'Item Code', titleAr: 'رمز الصنف', flex: 70),
      const ReportColumn(title: 'Item Name', titleAr: 'اسم الصنف', flex: 155),
      const ReportColumn(title: 'Warehouse', titleAr: 'المستودع', flex: 90),
      const ReportColumn(title: 'Qty on Hand', titleAr: 'الكمية', flex: 70, numeric: true),
      const ReportColumn(title: 'Avg Cost', titleAr: 'متوسط التكلفة', flex: 80, numeric: true),
      const ReportColumn(title: 'Total Value', titleAr: 'القيمة الإجمالية', flex: 90, numeric: true),
    ];

    final rows = <ReportRow>[];
    for (final c in data.categories) {
      rows.add(ReportRow.group(c.titleFor(dir)));
      for (final it in c.items) {
        rows.add(ReportRow([
          it.code,
          it.nameFor(dir),
          it.warehouseFor(dir),
          n(it.quantity),
          n(it.avgCost),
          n(it.totalValue),
        ]),);
      }
      rows.add(ReportRow(['', '', '', '', '', n(c.totalValue)], kind: RowKind.subtotal));
    }

    final grandBand = pw.Container(
      color: theme.palette.totalBand,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        children: theme.order([
          pw.Expanded(
            child: pw.Text(dir.isRtl ? 'إجمالي قيمة المخزون' : 'Total Inventory Value',
                style: theme.valueBold(), textDirection: theme.textDirection,),
          ),
          pw.Text(fmt.money(data.grandTotal, dir), style: theme.valueBold()),
        ]),
      ),
    );

    final body = <pw.Widget>[
      CompanyHeader(theme, data.company).build(),
      DocumentTitle(theme,
              titleEn: 'Inventory Valuation Report',
              titleAr: dir.isRtl ? 'تقرير تقييم المخزون' : null,
              subtitles: [
                dir.isRtl ? 'كما في ${fmt.date(data.asOf)}' : 'As of ${_longDate(data.asOf)}',
              ],
              printedAt: data.printedAt,
              format: fmt,)
          .build(),
      Gap.h(10),
      ...ReportDataTable(theme, ReportTableModel(columns: columns, rows: rows)).widgets(),
      grandBand,
    ];

    return ReportDocument.render(
      theme: theme,
      body: body,
      title: 'Inventory Valuation — ${data.company.name}',
      author: data.company.name,
      footer: PageFooter(theme, user: data.user, date: data.printedAt ?? data.asOf, format: fmt),
    );
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static String _longDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
