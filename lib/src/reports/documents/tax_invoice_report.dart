import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../components/company_header.dart';
import '../components/document_title.dart';
import '../components/info_section.dart';
import '../components/report_data_table.dart';
import '../components/signature_row.dart';
import '../components/totals_panel.dart';
import '../core/report_direction.dart';
import '../core/report_formatting.dart';
import '../core/report_models.dart';
import '../theme/report_theme.dart';
import 'report_document.dart';

/// A single invoice line item (bilingual description).
class InvoiceItem {
  const InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.nameAr,
    double? total,
  }) : _total = total;

  final String name;
  final String? nameAr;
  final double quantity;
  final double unitPrice;
  final double? _total;

  double get total => _total ?? quantity * unitPrice;
  String nameFor(ReportDir dir) => dir.isRtl ? (nameAr ?? name) : name;
}

/// Data for a VAT tax invoice matching the GeniusLink reference layout.
class InvoiceReportData {
  const InvoiceReportData({
    required this.company,
    required this.customer,
    required this.details,
    required this.items,
    required this.subtotal,
    required this.vatAmount,
    required this.total,
    this.vatRate = 15,
    this.currency = 'SAR',
    this.printedAt,
  });

  final ReportCompany company;
  final InfoPanel customer;
  final InfoPanel details;
  final List<InvoiceItem> items;
  final double subtotal;
  final double vatAmount;
  final double total;
  final double vatRate;
  final String currency;
  final DateTime? printedAt;
}

/// Builds the tax-invoice PDF (LTR or RTL) from [InvoiceReportData].
class TaxInvoiceReport {
  const TaxInvoiceReport(this.data, {this.dir = ReportDir.ltr});

  final InvoiceReportData data;
  final ReportDir dir;

  static const _titleEn = 'Tax Invoice';
  static const _titleAr = 'فاتورة ضريبية';

  Future<Uint8List> build(ReportTheme baseTheme) {
    final theme = baseTheme.withDir(dir);
    final fmt = ReportFormat(currencyCode: data.currency);
    String num2(double v) => fmt.number(v);
    String money(double v) => fmt.money(v, dir);

    final columns = <ReportColumn>[
      const ReportColumn(title: 'No.', titleAr: 'رقم', flex: 35, align: CellAlign.center),
      const ReportColumn(title: 'Item', titleAr: 'الصنف', flex: 290),
      const ReportColumn(title: 'Qty', titleAr: 'الكمية', flex: 60, align: CellAlign.center),
      const ReportColumn(title: 'Price', titleAr: 'السعر', flex: 80, numeric: true),
      const ReportColumn(title: 'Total', titleAr: 'الإجمالي', flex: 90, numeric: true),
    ];

    final rows = <ReportRow>[
      for (var i = 0; i < data.items.length; i++)
        ReportRow([
          '${i + 1}',
          data.items[i].nameFor(dir),
          fmt.number(data.items[i].quantity, decimals: 1),
          num2(data.items[i].unitPrice),
          num2(data.items[i].total),
        ]),
    ];

    final vatLabel = dir.isRtl
        ? 'ضريبة القيمة المضافة (${fmt.number(data.vatRate, decimals: 1)}%)'
        : 'VAT (${fmt.number(data.vatRate, decimals: 1)}%)';
    final totals = <TotalLine>[
      TotalLine(dir.isRtl ? 'الإجمالي قبل الضريبة' : 'Subtotal', money(data.subtotal)),
      TotalLine(vatLabel, money(data.vatAmount)),
      TotalLine(dir.isRtl ? 'الإجمالي الكلي' : 'Total Amount', money(data.total),
          emphasized: true,),
    ];

    final breakdown = dir.isRtl
        ? 'تفصيل الضريبة: الإجمالي الخاضع (${money(data.subtotal)})، مبلغ الضريبة (${money(data.vatAmount)})'
        : 'VAT Breakdown: Taxable Amount (${money(data.subtotal)}), VAT Amount (${money(data.vatAmount)})';

    final body = <pw.Widget>[
      CompanyHeader(theme, data.company).build(),
      DocumentTitle(theme,
              titleEn: _titleEn,
              titleAr: _titleAr,
              printedAt: data.printedAt,
              format: fmt,)
          .build(),
      Gap.h(6),
      InfoSection(theme, left: data.customer, right: data.details).build(),
      Gap.h(14),
      ...ReportDataTable(theme, ReportTableModel(columns: columns, rows: rows)).widgets(),
      Gap.h(12),
      TotalsPanel(theme, totals).build(),
      Gap.h(14),
      pw.Text(breakdown, style: theme.note(), textDirection: theme.textDirection),
      Gap.h(34),
      SignatureRow(theme, [
        const SignatureSlot('Authorized Signature', labelAr: 'التوقيع المعتمد'),
      ]).build(),
    ];

    return ReportDocument.render(
      theme: theme,
      body: body,
      title: '$_titleEn — ${data.company.name}',
      author: data.company.name,
    );
  }
}
