import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/report_models.dart';
import '../theme/report_theme.dart';

/// The grouped, zebra-striped data table at the heart of every report.
///
/// Renders a `#e0e0e0` header, `#f5f5f5` zebra data rows, full-width `#e3f2fd`
/// group bands, bold subtotal rows (hairline above), an emphasised `#e8e8e8`
/// total row and the dark `#424242` grand-total band — and mirrors the whole
/// column order for RTL while keeping numeric text upright.
class ReportDataTable {
  const ReportDataTable(this.theme, this.model);

  final ReportTheme theme;
  final ReportTableModel model;

  pw.TextAlign _align(CellAlign a) => switch (a) {
        CellAlign.start => theme.alignStart,
        CellAlign.center => pw.TextAlign.center,
        CellAlign.end => theme.alignEnd,
      };

  pw.Widget _cell(String text, ReportColumn col,
      {required pw.TextStyle style, bool numeric = false,}) {
    return pw.Expanded(
      flex: col.flex.round(),
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
        child: pw.Text(
          text,
          style: style,
          textAlign: _align(col.effectiveAlign),
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          textDirection: numeric ? pw.TextDirection.ltr : theme.textDirection,
        ),
      ),
    );
  }

  pw.Widget _headerRow() {
    final cells = [
      for (final c in model.columns)
        _cell(c.titleFor(theme.dir), c, style: theme.tableHeader()),
    ];
    return pw.Container(
      color: theme.palette.tableHeader,
      padding: const pw.EdgeInsets.symmetric(vertical: 6.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: theme.order(cells),
      ),
    );
  }

  pw.Widget _groupRow(String label) => pw.Container(
        color: theme.palette.groupBand,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(label,
                style: theme.groupHeader(),
                textAlign: theme.alignStart,
                textDirection: theme.textDirection,),
          ),
        ],),
      );

  pw.Widget _dataRow(ReportRow row, {required bool alt}) {
    final bold = row.kind == RowKind.subtotal;
    final grand = row.kind == RowKind.grand;
    final total = row.kind == RowKind.total;

    PdfColor? bg;
    if (grand) {
      bg = theme.palette.grandBand;
    } else if (total) {
      bg = theme.palette.totalBand;
    } else if (row.kind == RowKind.data && alt && model.zebra) {
      bg = theme.palette.zebra;
    }

    final textColor = grand ? theme.palette.grandBandText : theme.palette.text;

    final cells = <pw.Widget>[];
    for (var i = 0; i < model.columns.length; i++) {
      final col = model.columns[i];
      final text = i < row.cells.length ? row.cells[i] : '';
      cells.add(_cell(
        text,
        col,
        style: theme.tableCell(color: textColor, bold: bold || grand || total),
        numeric: col.numeric,
      ),);
    }

    return pw.Container(
      color: bg,
      decoration: row.kind == RowKind.subtotal
          ? pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: theme.palette.border, width: 0.7)),
            )
          : null,
      padding: pw.EdgeInsets.symmetric(vertical: grand ? 8 : 5.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: theme.order(cells),
      ),
    );
  }

  /// The table as a flat list of row widgets (header first). Spread this into a
  /// `MultiPage` body so long tables paginate **between rows** instead of
  /// overflowing a single tall column.
  List<pw.Widget> widgets() {
    final children = <pw.Widget>[_headerRow()];
    var dataIndex = 0;
    for (final row in model.rows) {
      switch (row.kind) {
        case RowKind.group:
          children.add(_groupRow(row.groupLabel));
          dataIndex = 0; // zebra restarts each group, matching the reference
        case RowKind.data:
          children.add(_dataRow(row, alt: dataIndex.isOdd));
          dataIndex++;
        case RowKind.subtotal:
        case RowKind.total:
        case RowKind.grand:
          children.add(_dataRow(row, alt: false));
      }
    }
    return children;
  }

  /// The table as a single column (for small, embedded tables like the aging
  /// analysis). For page-spanning tables prefer [widgets].
  pw.Widget build() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: widgets(),
      );
}
