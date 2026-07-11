import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../components/company_header.dart';
import '../components/document_title.dart';
import '../components/info_section.dart';
import '../components/report_data_table.dart';
import '../components/signature_row.dart';
import '../core/report_direction.dart';
import '../core/report_formatting.dart';
import '../core/report_models.dart';
import '../theme/report_theme.dart';
import 'report_document.dart';

/// One movement on a customer statement.
class StatementTxn {
  const StatementTxn({
    required this.date,
    required this.description,
    this.descriptionAr,
    this.reference = '-',
    this.debit = 0,
    this.credit = 0,
    required this.balance,
    this.closing = false,
  });

  final DateTime date;
  final String description;
  final String? descriptionAr;
  final String reference;
  final double debit;
  final double credit;
  final double balance;

  /// Marks the closing-balance row (rendered on the `#e8e8e8` total band).
  final bool closing;

  String descFor(ReportDir dir) => dir.isRtl ? (descriptionAr ?? description) : description;
}

/// Data for a customer statement of account matching the GeniusLink reference.
class CustomerStatementData {
  const CustomerStatementData({
    required this.company,
    required this.customer,
    required this.details,
    required this.transactions,
    required this.periodFrom,
    required this.periodTo,
    this.aging = const [],
    this.currency = 'SAR',
    this.printedAt,
  });

  final ReportCompany company;
  final InfoPanel customer;
  final InfoPanel details;
  final List<StatementTxn> transactions;
  final DateTime periodFrom;
  final DateTime periodTo;

  /// [0-30, 31-60, 61-90, +90] buckets; the total is computed.
  final List<double> aging;
  final String currency;
  final DateTime? printedAt;
}

/// Builds the customer-statement PDF (LTR or RTL) from [CustomerStatementData].
class CustomerStatementReport {
  const CustomerStatementReport(this.data, {this.dir = ReportDir.ltr});

  final CustomerStatementData data;
  final ReportDir dir;

  Future<Uint8List> build(ReportTheme baseTheme) {
    final theme = baseTheme.withDir(dir);
    final fmt = ReportFormat(currencyCode: data.currency);
    String amt(double v) => v == 0 ? '' : fmt.number(v);

    final columns = <ReportColumn>[
      const ReportColumn(title: 'Date', titleAr: 'التاريخ', flex: 70, align: CellAlign.center),
      const ReportColumn(title: 'Ref No.', titleAr: 'المرجع', flex: 70, align: CellAlign.center),
      const ReportColumn(title: 'Description', titleAr: 'البيان', flex: 165),
      const ReportColumn(title: 'Debit', titleAr: 'مدين', flex: 80, numeric: true),
      const ReportColumn(title: 'Credit', titleAr: 'دائن', flex: 80, numeric: true),
      const ReportColumn(title: 'Balance', titleAr: 'الرصيد', flex: 90, numeric: true),
    ];

    final rows = <ReportRow>[
      for (final t in data.transactions)
        ReportRow([
          fmt.date(t.date),
          t.reference,
          t.descFor(dir),
          amt(t.debit),
          amt(t.credit),
          fmt.number(t.balance),
        ], kind: t.closing ? RowKind.total : RowKind.data,),
    ];

    // Aging analysis — a compact 5-column table.
    final agingCols = <ReportColumn>[
      const ReportColumn(title: '0-30 Days', titleAr: '0-30 يوم', flex: 1, align: CellAlign.center),
      const ReportColumn(title: '31-60 Days', titleAr: '31-60 يوم', flex: 1, align: CellAlign.center),
      const ReportColumn(title: '61-90 Days', titleAr: '61-90 يوم', flex: 1, align: CellAlign.center),
      const ReportColumn(title: '+90 Days', titleAr: '+90 يوم', flex: 1, align: CellAlign.center),
      const ReportColumn(title: 'Total', titleAr: 'الإجمالي', flex: 1, align: CellAlign.center),
    ];
    final agingTotal = data.aging.fold(0.0, (s, v) => s + v);
    final agingRows = <ReportRow>[
      ReportRow([
        for (final v in data.aging) fmt.number(v),
        fmt.number(agingTotal),
      ]),
    ];

    final periodEn =
        'Period From: ${fmt.date(data.periodFrom)} To: ${fmt.date(data.periodTo)}';
    final periodAr =
        'الفترة من: ${fmt.date(data.periodFrom)} إلى: ${fmt.date(data.periodTo)}';

    final body = <pw.Widget>[
      CompanyHeader(theme, data.company).build(),
      DocumentTitle(theme,
              titleEn: 'Customer Statement of Account',
              titleAr: 'كشف حساب عميل',
              subtitles: [periodAr, periodEn],
              printedAt: data.printedAt,
              format: fmt,)
          .build(),
      Gap.h(6),
      InfoSection(theme, left: data.customer, right: data.details).build(),
      Gap.h(14),
      ...ReportDataTable(theme, ReportTableModel(columns: columns, rows: rows)).widgets(),
      if (data.aging.isNotEmpty) ...[
        Gap.h(16),
        pw.Text(dir.isRtl ? 'تحليل أعمار الديون:' : 'Aging Analysis:',
            style: theme.valueBold(), textDirection: theme.textDirection,),
        Gap.h(6),
        ReportDataTable(theme,
                ReportTableModel(columns: agingCols, rows: agingRows, zebra: false),)
            .build(),
      ],
      Gap.h(30),
      SignatureRow(theme, [
        const SignatureSlot('Authorized Signature', labelAr: 'التوقيع المعتمد'),
        const SignatureSlot('Date', labelAr: 'التاريخ'),
      ]).build(),
    ];

    return ReportDocument.render(
      theme: theme,
      body: body,
      title: 'Customer Statement — ${data.company.name}',
      author: data.company.name,
    );
  }
}
