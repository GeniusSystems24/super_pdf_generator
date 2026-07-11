import 'package:pdf/widgets.dart' as pw;

import '../core/report_formatting.dart';
import '../theme/report_theme.dart';

/// The centered title block beneath the company header: an Arabic title, the
/// English title below it, one or more muted subtitles, and — pinned to the
/// trailing top corner — the "Printed:" timestamp.
class DocumentTitle {
  const DocumentTitle(
    this.theme, {
    required this.titleEn,
    this.titleAr,
    this.subtitles = const [],
    this.printedAt,
    this.format = const ReportFormat(),
  });

  final ReportTheme theme;
  final String titleEn;
  final String? titleAr;
  final List<String> subtitles;
  final DateTime? printedAt;
  final ReportFormat format;

  pw.Widget build() {
    final hasAr = titleAr != null && titleAr!.isNotEmpty;

    final titleCol = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (hasAr) ...[
          pw.Text(titleAr!,
              style: theme.arabic(size: theme.scale.titleArabic, bold: true),
              textDirection: pw.TextDirection.rtl,),
          pw.SizedBox(height: 3),
        ],
        pw.Text(titleEn, style: theme.title()),
        for (final s in subtitles) ...[
          pw.SizedBox(height: 2),
          pw.Text(s,
              style: theme.subtitle(),
              textAlign: pw.TextAlign.center,
              textDirection: theme.textDirection,),
        ],
      ],
    );

    // Balanced Expanded on both sides keeps the title optically centered while
    // the "Printed:" stamp sits in the trailing gutter, level with the title.
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.SizedBox()),
          titleCol,
          pw.Expanded(
            child: printedAt == null
                ? pw.SizedBox()
                : pw.Align(
                    alignment: pw.Alignment.topRight,
                    child: pw.Text('Printed: ${format.dateTime(printedAt!)}',
                        style: theme.printed(),),
                  ),
          ),
        ],
      ),
    );
  }
}
