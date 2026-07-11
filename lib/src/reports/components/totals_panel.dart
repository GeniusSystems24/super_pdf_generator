import 'package:pdf/widgets.dart' as pw;

import '../theme/report_theme.dart';

/// One line in a [TotalsPanel].
class TotalLine {
  const TotalLine(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;

  /// Draws the `#e8e8e8` band and bold type (the grand-total row).
  final bool emphasized;
}

/// The right-aligned totals stack under an invoice table: label/value rows with
/// the grand total on an `#e8e8e8` band. Per the reference the panel stays on
/// the page's right edge in both directions; only each row's label/value order
/// mirrors for RTL.
class TotalsPanel {
  const TotalsPanel(this.theme, this.lines, {this.width = 224});

  final ReportTheme theme;
  final List<TotalLine> lines;
  final double width;

  pw.Widget _row(TotalLine line) {
    final children = [
      pw.Expanded(
        child: pw.Text(line.label,
            style: line.emphasized ? theme.valueBold() : theme.value(color: theme.palette.textMuted),
            textAlign: theme.alignStart,
            textDirection: theme.textDirection,),
      ),
      pw.Text(line.value,
          style: line.emphasized ? theme.valueBold() : theme.value(),
          textDirection: theme.textDirection,),
    ];
    return pw.Container(
      color: line.emphasized ? theme.palette.totalBand : null,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: pw.Row(children: theme.order(children)),
    );
  }

  pw.Widget build() {
    return pw.Row(
      children: [
        pw.Spacer(),
        pw.SizedBox(
          width: width,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [for (final l in lines) _row(l)],
          ),
        ),
      ],
    );
  }
}
