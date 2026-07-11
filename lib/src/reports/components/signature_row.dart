import 'package:pdf/widgets.dart' as pw;

import '../core/report_models.dart';
import '../theme/report_theme.dart';

/// A row of signing columns (line + role label), each with empty signing space
/// above the rule. One slot aligns to the leading edge; two split to the edges;
/// three spread start / center / end (Prepared / Reviewed / Approved).
class SignatureRow {
  const SignatureRow(this.theme, this.slots, {this.lineWidth = 150, this.space = 26});

  final ReportTheme theme;
  final List<SignatureSlot> slots;
  final double lineWidth;
  final double space;

  pw.CrossAxisAlignment _cross(int i) {
    if (slots.length == 1) return theme.crossStart;
    if (slots.length == 2) return i == 0 ? theme.crossStart : theme.crossEnd;
    if (i == 0) return theme.crossStart;
    if (i == slots.length - 1) return theme.crossEnd;
    return pw.CrossAxisAlignment.center;
  }

  pw.Widget _slot(SignatureSlot s, int i) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: _cross(i),
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (s.name != null) ...[
            pw.Text(s.name!, style: theme.value()),
            pw.SizedBox(height: 2),
          ] else
            pw.SizedBox(height: space),
          pw.Container(width: lineWidth, height: 0.8, color: theme.palette.rule),
          pw.SizedBox(height: 3),
          pw.Text(s.labelFor(theme.dir),
              style: theme.signature(), textDirection: theme.textDirection,),
        ],
      ),
    );
  }

  pw.Widget build() => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [for (var i = 0; i < slots.length; i++) _slot(slots[i], i)],
      );
}
