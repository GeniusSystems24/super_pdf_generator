import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'report_direction.dart';

/// A bilingual string: pick [en] or [ar] by direction. When the Arabic side is
/// omitted the English value is used for both, so callers can supply only what
/// they have.
class Bilingual {
  const Bilingual(this.en, [this.ar]);
  final String en;
  final String? ar;

  String pick(ReportDir dir) => dir.isRtl ? (ar ?? en) : en;

  /// The value for the given direction, falling back across languages.
  String of(ReportDir dir) => pick(dir);

  static const Bilingual empty = Bilingual('');
}

/// Horizontal alignment intent for a table column / cell, resolved against
/// direction by the components (start = leading edge, end = trailing edge).
enum CellAlign { start, center, end }

/// The issuing company shown in the report header. English + Arabic details sit
/// on opposite sides of a centered (optional) logo.
class ReportCompany {
  const ReportCompany({
    required this.name,
    this.nameAr,
    this.address,
    this.addressAr,
    this.vatNumber,
    this.crNumber,
    this.phone,
    this.email,
    this.tagline,
    this.logo,
  });

  final String name;
  final String? nameAr;
  final String? address;
  final String? addressAr;
  final String? vatNumber;
  final String? crNumber;
  final String? phone;
  final String? email;
  final String? tagline;

  /// Optional raster logo (PNG/JPEG bytes) drawn centered between the two
  /// language columns.
  final Uint8List? logo;
}

/// A single label→value line inside an [InfoPanel].
class InfoField {
  const InfoField(this.label, this.value, {this.labelAr, this.strong = false});
  final String label;
  final String? labelAr;
  final String value;
  final bool strong;

  String labelFor(ReportDir dir) => dir.isRtl ? (labelAr ?? label) : label;
}

/// A titled key/value panel (the "To" / "Invoice Details" boxes). Two panels
/// sit side by side in the info section.
class InfoPanel {
  const InfoPanel({required this.title, required this.fields, this.titleAr});
  final String title;
  final String? titleAr;
  final List<InfoField> fields;

  String titleFor(ReportDir dir) => dir.isRtl ? (titleAr ?? title) : title;
}

/// A data-table column definition. [flex] sets the relative width; the row of
/// flexes is normalised to the content width.
class ReportColumn {
  const ReportColumn({
    required this.title,
    this.titleAr,
    this.flex = 1,
    this.align = CellAlign.start,
    this.numeric = false,
  });

  final String title;
  final String? titleAr;

  /// Relative width. For the reference tables these are the exact point widths
  /// (e.g. 70/155/90/…); any proportional set works.
  final double flex;

  /// Logical alignment. Numeric columns default to trailing-edge alignment.
  final CellAlign align;

  /// Marks money/number columns (kept trailing-aligned and never mirrored to
  /// RTL glyph order).
  final bool numeric;

  String titleFor(ReportDir dir) => dir.isRtl ? (titleAr ?? title) : title;
  CellAlign get effectiveAlign =>
      align == CellAlign.start && numeric ? CellAlign.end : align;
}

/// The visual role of a table row.
enum RowKind {
  /// Ordinary data row (zebra-striped).
  data,

  /// A full-width category band (`#e3f2fd`) that opens a group.
  group,

  /// A group subtotal row (bold, hairline above).
  subtotal,

  /// An emphasised total row (`#e8e8e8` band).
  total,

  /// The dark grand-total band (`#424242`, white text).
  grand,
}

/// One row of a [ReportTableModel]. For [RowKind.group] only [cells].first is
/// used as the band label.
class ReportRow {
  const ReportRow(this.cells, {this.kind = RowKind.data}):_groupLabel=null;
  const ReportRow.group(String label)
      : cells = const [],
        _groupLabel = label,
        kind = RowKind.group;

  final List<String> cells;
  final RowKind kind;
  final String? _groupLabel;

  String get groupLabel => _groupLabel ?? (cells.isNotEmpty ? cells.first : '');
}

/// A full table model: columns + rows, with zebra striping applied to
/// [RowKind.data] rows only.
class ReportTableModel {
  const ReportTableModel({required this.columns, required this.rows, this.zebra = true});
  final List<ReportColumn> columns;
  final List<ReportRow> rows;
  final bool zebra;
}

/// The role of a summary line, driving its tint and weight.
enum SummaryKind {
  /// Normal label→value line.
  item,

  /// A group subtotal — green tint (`#e8f5e9`).
  subtotalPositive,

  /// A deduction/expense subtotal — red tint (`#ffebee`).
  subtotalNegative,

  /// The final total — gray band (`#e8e8e8`), larger type.
  total,

  /// A group heading line (bold, no value).
  heading,
}

/// One line inside a [SummaryModel] or [SummaryGroup].
class SummaryLine {
  const SummaryLine(
    this.label,
    this.value, {
    this.labelAr,
    this.kind = SummaryKind.item,
    this.indent = 0,
    this.deduction = false,
  });

  final String label;
  final String? labelAr;

  /// Pre-formatted value string (e.g. `SAR 30,100.00`). Summary values are
  /// supplied already formatted so callers control symbol placement.
  final String value;
  final SummaryKind kind;

  /// Indent level for hierarchical summaries.
  final int indent;

  /// Renders the value with a leading `-` and the negative tint.
  final bool deduction;

  String labelFor(ReportDir dir) => dir.isRtl ? (labelAr ?? label) : label;
}

/// A titled group of summary lines (colored header + items + subtotal).
class SummaryGroup {
  const SummaryGroup({required this.title, required this.lines, this.titleAr, this.color});
  final String title;
  final String? titleAr;
  final List<SummaryLine> lines;

  /// Optional group-header tint (defaults to the light-blue group band).
  final PdfColor? color;

  String titleFor(ReportDir dir) => dir.isRtl ? (titleAr ?? title) : title;
}

/// The visual preset for [SummaryBox].
enum SummaryStyle {
  /// Title bar + light surface, emphasised total (the invoice summary).
  invoice,

  /// Rounded card with a light-blue title bar.
  card,

  /// Border only, no fill.
  bordered,

  /// No chrome — rows only.
  minimal,
}

/// A complete summary model (flat lines and/or groups) rendered by [SummaryBox].
class SummaryModel {
  const SummaryModel({
    this.title,
    this.titleAr,
    this.lines = const [],
    this.groups = const [],
    this.style = SummaryStyle.invoice,
    this.width,
  });

  final String? title;
  final String? titleAr;
  final List<SummaryLine> lines;
  final List<SummaryGroup> groups;
  final SummaryStyle style;

  /// Fixed box width in points; when null the box fills its slot.
  final double? width;

  String? titleFor(ReportDir dir) =>
      title == null ? null : (dir.isRtl ? (titleAr ?? title) : title);
}

/// One signing column (line + role label, optional name/date caption).
class SignatureSlot {
  const SignatureSlot(this.label, {this.labelAr, this.name});
  final String label;
  final String? labelAr;
  final String? name;

  String labelFor(ReportDir dir) => dir.isRtl ? (labelAr ?? label) : label;
}
