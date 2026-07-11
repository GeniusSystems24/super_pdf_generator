import 'package:pdf/widgets.dart' as pw;

import '../core/report_formatting.dart';
import '../theme/report_theme.dart';

/// The running footer band used by multi-page reports: a top hairline then the
/// operator, the report date, and the page number ("1/2") on the trailing edge.
class PageFooter {
  const PageFooter(
    this.theme, {
    this.user,
    this.date,
    this.showPageNumber = true,
    this.format = const ReportFormat(),
  });

  final ReportTheme theme;
  final String? user;
  final DateTime? date;
  final bool showPageNumber;
  final ReportFormat format;

  /// Builds the footer for a given page context (MultiPage `footer:`).
  pw.Widget build(pw.Context context) {
    final left = pw.Expanded(
      flex: 5,
      child: pw.Text(user != null ? 'User: $user' : '',
          style: theme.footer(), textAlign: theme.alignStart,),
    );
    final mid = pw.Expanded(
      flex: 4,
      child: pw.Text(date != null ? format.date(date!) : '',
          style: theme.footer(), textAlign: theme.alignStart,),
    );
    final right = pw.Expanded(
      flex: 2,
      child: pw.Text(
          showPageNumber ? '${context.pageNumber}/${context.pagesCount}' : '',
          style: theme.footer(),
          textAlign: theme.alignEnd,),
    );

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: theme.palette.border, width: 0.7)),
      ),
      child: pw.Row(children: theme.order([left, mid, right])),
    );
  }
}
