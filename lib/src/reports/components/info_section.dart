import 'package:pdf/widgets.dart' as pw;

import '../core/report_models.dart';
import '../theme/report_theme.dart';

/// The info section: two titled key/value panels side by side (e.g. "To" and
/// "Invoice Details"). The panels keep their screen sides in both directions;
/// only the label/value order inside each row mirrors for RTL.
class InfoSection {
  const InfoSection(this.theme, {required this.left, this.right, this.labelFlex = 0.42});

  final ReportTheme theme;
  final InfoPanel left;
  final InfoPanel? right;

  /// Share of the panel width given to the label column.
  final double labelFlex;

  pw.Widget _panel(InfoPanel panel) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: theme.palette.border, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // Header bar.
          pw.Container(
            color: theme.palette.boxHeader,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            alignment: pw.Alignment.center,
            child: pw.Text(panel.titleFor(theme.dir),
                style: theme.boxHeader(), textDirection: theme.textDirection,),
          ),
          // Rows.
          for (final f in panel.fields) _row(f),
        ],
      ),
    );
  }

  pw.Widget _row(InfoField f) {
    final labelWidgets = <pw.Widget>[
      pw.Expanded(
        flex: (labelFlex * 100).round(),
        child: pw.Text(f.labelFor(theme.dir),
            style: theme.label(),
            textAlign: theme.alignStart,
            textDirection: theme.textDirection,),
      ),
      pw.Expanded(
        flex: ((1 - labelFlex) * 100).round(),
        child: pw.Text(f.value,
            style: theme.value(color: f.strong ? theme.palette.text : null),
            textAlign: theme.alignStart,
            textDirection: theme.textDirection,),
      ),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: theme.order(labelWidgets),
      ),
    );
  }

  pw.Widget build() {
    if (right == null) return _panel(left);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _panel(left)),
        pw.SizedBox(width: 15),
        pw.Expanded(child: _panel(right!)),
      ],
    );
  }
}
