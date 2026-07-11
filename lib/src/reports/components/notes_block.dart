import 'package:pdf/widgets.dart' as pw;

import '../theme/report_theme.dart';

/// A bulleted notes block with an optional trailing reference (e.g. "ID: …")
/// aligned to the header's trailing edge.
class NotesBlock {
  const NotesBlock(
    this.theme, {
    required this.notes,
    this.heading = 'Notes:',
    this.headingAr,
    this.reference,
  });

  final ReportTheme theme;
  final List<String> notes;
  final String heading;
  final String? headingAr;
  final String? reference;

  pw.Widget build() {
    final headingText = theme.dir.isRtl ? (headingAr ?? heading) : heading;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Row(
          children: theme.order([
            pw.Expanded(
              child: pw.Text(headingText,
                  style: theme.valueBold(), textDirection: theme.textDirection,),
            ),
            if (reference != null)
              pw.Text(reference!, style: theme.note()),
          ]),
        ),
        pw.SizedBox(height: 5),
        for (final n in notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: theme.order([
                pw.Container(
                  width: 12,
                  alignment: theme.boxTopStart,
                  child: pw.Text('•', style: theme.note()),
                ),
                pw.Expanded(
                  child: pw.Text(n,
                      style: theme.note(),
                      textAlign: theme.alignStart,
                      textDirection: theme.textDirection,),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
