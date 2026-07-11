import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/report_models.dart';
import '../theme/report_theme.dart';

/// The GeniusPdfSummary component: a titled totals box with four visual presets
/// (invoice / card / bordered / minimal), optional grouped sections, and
/// semantic subtotal tints — green (`#e8f5e9`) for positive subtotals, red
/// (`#ffebee`) for deductions, gray (`#e8e8e8`) for the final total.
class SummaryBox {
  const SummaryBox(this.theme, this.model, {this.valueWidth = 110});

  final ReportTheme theme;
  final SummaryModel model;
  final double valueWidth;

  bool get _minimal => model.style == SummaryStyle.minimal;

  PdfColor? _rowBg(SummaryLine l) => switch (l.kind) {
        SummaryKind.subtotalPositive => theme.palette.positive,
        SummaryKind.subtotalNegative => theme.palette.negative,
        // The invoice-style final total is a bordered emphasis, not a band;
        // grouped/other totals sit on the gray band.
        SummaryKind.total =>
          model.style == SummaryStyle.invoice ? null : theme.palette.totalBand,
        _ => null,
      };

  PdfColor _labelColor(SummaryLine l) => switch (l.kind) {
        SummaryKind.subtotalPositive => theme.palette.positiveText,
        SummaryKind.subtotalNegative => theme.palette.negativeText,
        SummaryKind.total => theme.palette.text,
        SummaryKind.heading => theme.palette.text,
        SummaryKind.item => theme.palette.textMuted,
      };

  PdfColor _valueColor(SummaryLine l) {
    if (l.deduction) return theme.palette.negativeText;
    return switch (l.kind) {
      SummaryKind.subtotalPositive => theme.palette.positiveText,
      SummaryKind.subtotalNegative => theme.palette.negativeText,
      _ => theme.palette.text,
    };
  }

  pw.Widget _lineRow(SummaryLine l) {
    final isTotal = l.kind == SummaryKind.total;
    final isSub = l.kind == SummaryKind.subtotalPositive ||
        l.kind == SummaryKind.subtotalNegative;
    final strong = isTotal || isSub || l.kind == SummaryKind.heading;

    final labelStyle = isTotal
        ? theme.summaryTotal(color: _labelColor(l))
        : (strong
            ? theme.summaryRowValue(color: _labelColor(l), bold: true)
            : theme.summaryRowLabel());
    final valueStyle = isTotal
        ? theme.summaryTotal(color: _valueColor(l))
        : theme.summaryRowValue(color: _valueColor(l), bold: strong);

    final label = pw.Expanded(
      child: pw.Padding(
        padding: pw.EdgeInsets.only(
          left: theme.dir.isLtr ? l.indent * 12.0 : 0,
          right: theme.dir.isRtl ? l.indent * 12.0 : 0,
        ),
        child: pw.Text(l.labelFor(theme.dir),
            style: labelStyle,
            textAlign: theme.alignStart,
            textDirection: theme.textDirection,),
      ),
    );
    final value = pw.SizedBox(
      width: valueWidth,
      child: pw.Text(l.value,
          style: valueStyle,
          textAlign: theme.alignEnd,
          textDirection: theme.textDirection,),
    );

    final bg = _rowBg(l);
    final topBorder = isTotal && model.style == SummaryStyle.invoice;
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: isTotal ? 5 : 3, horizontal: _minimal ? 0 : 8),
      decoration: (bg != null || topBorder)
          ? pw.BoxDecoration(
              color: bg,
              border: topBorder
                  ? pw.Border(top: pw.BorderSide(color: theme.palette.border, width: 0.8))
                  : null,
            )
          : null,
      child: pw.Row(children: theme.order([label, value])),
    );
  }

  pw.Widget _groupHeader(SummaryGroup g) => pw.Container(
        color: g.color ?? theme.palette.groupBand,
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: pw.Text(g.titleFor(theme.dir),
            style: theme.groupHeader(
                color: g.color != null ? theme.palette.text : theme.palette.groupBandText,),
            textAlign: theme.alignStart,
            textDirection: theme.textDirection,),
      );

  pw.Widget _titleBar() {
    final title = model.titleFor(theme.dir)!;
    if (_minimal) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(title,
            style: theme.summaryTitle(), textDirection: theme.textDirection,),
      );
    }
    final barColor = model.style == SummaryStyle.card
        ? theme.palette.groupBand
        : theme.palette.surfaceHeader;
    return pw.Container(
      color: model.style == SummaryStyle.bordered ? null : barColor,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      alignment: pw.Alignment.center,
      decoration: model.style == SummaryStyle.bordered
          ? pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: theme.palette.border)),)
          : null,
      child: pw.Text(title,
          style: theme.summaryTitle(), textDirection: theme.textDirection,),
    );
  }

  pw.BoxDecoration? _boxDecoration() {
    switch (model.style) {
      case SummaryStyle.invoice:
        return pw.BoxDecoration(
          color: theme.palette.surface,
          border: pw.Border.all(color: theme.palette.border, width: 0.7),
        );
      case SummaryStyle.card:
        return pw.BoxDecoration(
          color: theme.palette.surfaceAlt,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: theme.palette.borderSoft, width: 0.7),
        );
      case SummaryStyle.bordered:
        return pw.BoxDecoration(
          border: pw.Border.all(color: theme.palette.border, width: 0.8),
        );
      case SummaryStyle.minimal:
        return null;
    }
  }

  pw.Widget build() {
    final rows = <pw.Widget>[];
    if (model.title != null) rows.add(_titleBar());

    final bodyChildren = <pw.Widget>[
      for (final l in model.lines) _lineRow(l),
      for (final g in model.groups) ...[
        _groupHeader(g),
        for (final l in g.lines) _lineRow(l),
      ],
    ];

    rows.add(pw.Padding(
      padding: _minimal ? pw.EdgeInsets.zero : const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: bodyChildren,
      ),
    ),);

    final box = pw.Container(
      width: model.width,
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: rows,
      ),
    );

    // When a fixed width is set, keep the box on the trailing edge like the
    // reference; otherwise let it fill its slot.
    if (model.width != null) {
      return pw.Row(children: theme.order([pw.Spacer(), box]));
    }
    return box;
  }
}
