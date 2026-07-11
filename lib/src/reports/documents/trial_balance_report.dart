import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../components/company_header.dart';
import '../components/document_title.dart';
import '../components/notes_block.dart';
import '../components/page_footer.dart';
import '../components/qr_panel.dart';
import '../components/report_data_table.dart';
import '../components/signature_row.dart';
import '../components/summary_box.dart';
import '../core/report_direction.dart';
import '../core/report_formatting.dart';
import '../core/report_models.dart';
import '../theme/report_theme.dart';
import 'report_document.dart';

/// One account line in a trial balance (a debit *or* a credit balance).
class TrialBalanceAccount {
  const TrialBalanceAccount(this.name, {this.nameAr, this.debit = 0, this.credit = 0});
  final String name;
  final String? nameAr;
  final double debit;
  final double credit;
  String nameFor(ReportDir dir) => dir.isRtl ? (nameAr ?? name) : name;
}

/// A category of accounts (Assets, Liabilities, …) with a computed subtotal.
class TrialBalanceGroup {
  const TrialBalanceGroup(this.title, this.accounts, {this.titleAr});
  final String title;
  final String? titleAr;
  final List<TrialBalanceAccount> accounts;

  double get debit => accounts.fold(0.0, (s, a) => s + a.debit);
  double get credit => accounts.fold(0.0, (s, a) => s + a.credit);
  String titleFor(ReportDir dir) => dir.isRtl ? (titleAr ?? title) : title;
}

/// Data for a trial balance report matching the GeniusLink reference.
class TrialBalanceData {
  const TrialBalanceData({
    required this.company,
    required this.asOf,
    required this.groups,
    this.notes = const [],
    this.documentId,
    this.qrData,
    this.user,
    this.currency = 'SAR',
    this.printedAt,
  });

  final ReportCompany company;
  final DateTime asOf;
  final List<TrialBalanceGroup> groups;
  final List<String> notes;
  final String? documentId;
  final String? qrData;
  final String? user;
  final String currency;
  final DateTime? printedAt;

  double get totalDebit => groups.fold(0.0, (s, g) => s + g.debit);
  double get totalCredit => groups.fold(0.0, (s, g) => s + g.credit);
  int get accountCount => groups.fold(0, (s, g) => s + g.accounts.length);
}

/// Builds the trial-balance PDF (LTR or RTL) from [TrialBalanceData].
class TrialBalanceReport {
  const TrialBalanceReport(this.data, {this.dir = ReportDir.ltr});

  final TrialBalanceData data;
  final ReportDir dir;

  Future<Uint8List> build(ReportTheme baseTheme) {
    final theme = baseTheme.withDir(dir);
    final fmt = ReportFormat(currencyCode: data.currency);
    String cell(double v) => v == 0 ? '' : fmt.number(v);
    String sub(double v) => fmt.number(v);

    final columns = <ReportColumn>[
      const ReportColumn(title: 'Account Name', titleAr: 'اسم الحساب', flex: 299),
      const ReportColumn(title: 'Debit', titleAr: 'مدين', flex: 128, numeric: true),
      const ReportColumn(title: 'Credit', titleAr: 'دائن', flex: 128, numeric: true),
    ];

    final rows = <ReportRow>[];
    for (final g in data.groups) {
      rows.add(ReportRow.group(g.titleFor(dir)));
      for (final a in g.accounts) {
        rows.add(ReportRow([a.nameFor(dir), cell(a.debit), cell(a.credit)]));
      }
      rows.add(ReportRow(['', sub(g.debit), sub(g.credit)], kind: RowKind.subtotal));
    }

    final grandBand = pw.Container(
      color: theme.palette.grandBand,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Row(
        children: theme.order([
          pw.Expanded(
            child: pw.Text(dir.isRtl ? 'الإجمالي' : 'Total',
                style: theme.grandTotal(), textDirection: theme.textDirection,),
          ),
          pw.Text(fmt.money(data.totalDebit, dir), style: theme.grandTotal()),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Text('|', style: theme.grandTotal(color: theme.palette.border)),
          ),
          pw.Text(fmt.money(data.totalCredit, dir), style: theme.grandTotal()),
        ]),
      ),
    );

    // ---- page 2 end matter --------------------------------------------------
    final difference = data.totalDebit - data.totalCredit;
    final summary = SummaryModel(
      style: SummaryStyle.bordered,
      width: 250,
      lines: [
        SummaryLine(dir.isRtl ? 'إجمالي الحسابات' : 'Total Accounts', '${data.accountCount}'),
        SummaryLine(dir.isRtl ? 'عدد الفئات' : 'Categories', '${data.groups.length}'),
        SummaryLine(dir.isRtl ? 'إجمالي المدين' : 'Total Debit', fmt.money(data.totalDebit, dir)),
        SummaryLine(dir.isRtl ? 'إجمالي الدائن' : 'Total Credit', fmt.money(data.totalCredit, dir)),
        SummaryLine(dir.isRtl ? 'الفرق' : 'Difference', fmt.money(difference, dir),
            kind: SummaryKind.total,),
      ],
    );

    final body = <pw.Widget>[
      CompanyHeader(theme, data.company).build(),
      DocumentTitle(theme,
              titleEn: 'Trial Balance',
              titleAr: 'ميزان المراجعة',
              subtitles: [
                dir.isRtl
                    ? 'كما في ${fmt.date(data.asOf)}'
                    : 'As of ${_longDate(data.asOf)}',
              ],
              printedAt: data.printedAt,
              format: fmt,)
          .build(),
      Gap.h(10),
      ...ReportDataTable(theme, ReportTableModel(columns: columns, rows: rows)).widgets(),
      grandBand,
      pw.NewPage(),
      SummaryBox(theme, summary).build(),
      Gap.h(16),
      if (data.notes.isNotEmpty)
        NotesBlock(theme,
                notes: data.notes,
                headingAr: 'ملاحظات:',
                reference: data.documentId == null ? null : 'ID: ${data.documentId}',)
            .build(),
      Gap.h(14),
      if (data.qrData != null)
        pw.Align(
          alignment: theme.boxEnd,
          child: QrPanel(theme, data: data.qrData!, captionAr: 'امسح للفتح').build(),
        ),
      Gap.h(30),
      SignatureRow(theme, [
        const SignatureSlot('Prepared By', labelAr: 'أعدّ بواسطة'),
        const SignatureSlot('Reviewed By', labelAr: 'روجع بواسطة'),
        const SignatureSlot('Approved By', labelAr: 'اعتمد بواسطة'),
      ]).build(),
    ];

    return ReportDocument.render(
      theme: theme,
      body: body,
      title: 'Trial Balance — ${data.company.name}',
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
