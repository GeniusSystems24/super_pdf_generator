import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/report_direction.dart';
import 'report_fonts.dart';
import 'report_palette.dart';
import 'report_type_scale.dart';

/// The single object every report component reads from: it bundles the palette,
/// the type scale, the loaded fonts and the reading direction, and hands out
/// ready-made [pw.TextStyle]s and direction helpers so callers never assemble a
/// style — or reason about mirroring — by hand.
class ReportTheme {
  ReportTheme({
    required this.fonts,
    this.palette = ReportPalette.standard,
    this.scale = ReportTypeScale.standard,
    this.dir = ReportDir.ltr,
  });

  final ReportFonts fonts;
  final ReportPalette palette;
  final ReportTypeScale scale;
  final ReportDir dir;

  bool get rtl => dir.isRtl;

  /// A copy of this theme in the given direction (used to render both variants
  /// from one configured theme).
  ReportTheme withDir(ReportDir d) =>
      ReportTheme(fonts: fonts, palette: palette, scale: scale, dir: d);

  // ---- direction helpers --------------------------------------------------

  pw.TextDirection get textDirection =>
      rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  /// Alignment for content that leads the line (labels, first column).
  pw.TextAlign get alignStart => rtl ? pw.TextAlign.right : pw.TextAlign.left;

  /// Alignment for content that trails the line (values, last column).
  pw.TextAlign get alignEnd => rtl ? pw.TextAlign.left : pw.TextAlign.right;

  pw.Alignment get boxStart =>
      rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
  pw.Alignment get boxEnd =>
      rtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight;
  pw.Alignment get boxTopStart =>
      rtl ? pw.Alignment.topRight : pw.Alignment.topLeft;

  pw.CrossAxisAlignment get crossStart =>
      rtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;
  pw.CrossAxisAlignment get crossEnd =>
      rtl ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end;

  /// Reverses a horizontal run of children when in RTL, so the visual order of
  /// columns/cells mirrors while the source stays logical (start → end).
  List<T> order<T>(List<T> logical) =>
      rtl ? logical.reversed.toList(growable: false) : logical;

  // ---- pdf document theme -------------------------------------------------

  pw.ThemeData buildPageTheme() => pw.ThemeData.withFont(
        base: fonts.latinRegular,
        bold: fonts.latinBold,
        fontFallback: fonts.regularFallback,
      ).copyWith(defaultTextStyle: value());

  // ---- text styles --------------------------------------------------------

  pw.TextStyle _s({
    required double size,
    bool bold = false,
    PdfColor? color,
    double? letterSpacing,
    double? lineSpacing,
  }) =>
      pw.TextStyle(
        font: bold ? fonts.latinBold : fonts.latinRegular,
        fontFallback: bold ? fonts.boldFallback : fonts.regularFallback,
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? palette.text,
        letterSpacing: letterSpacing,
        lineSpacing: lineSpacing,
      );

  /// A style forced onto the Arabic face (used for the Arabic header/title runs
  /// so their metrics match the reference even inside a mixed document).
  pw.TextStyle arabic({required double size, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        font: bold ? fonts.arabicBold : fonts.arabicRegular,
        fontFallback: bold ? fonts.boldFallback : fonts.regularFallback,
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? palette.text,
      );

  pw.TextStyle companyName() =>
      _s(size: scale.companyName, bold: true, color: palette.text);
  pw.TextStyle companyInfo() =>
      _s(size: scale.companyInfo, color: palette.textMuted);
  pw.TextStyle title() => _s(size: scale.title, bold: true, color: palette.text);
  pw.TextStyle subtitle() => _s(size: scale.subtitle, color: palette.textMuted);
  pw.TextStyle printed() => _s(size: scale.printed, color: palette.textFaint);
  pw.TextStyle boxHeader() =>
      _s(size: scale.boxHeader, bold: true, color: palette.text);
  pw.TextStyle label() => _s(size: scale.label, color: palette.textMuted);
  pw.TextStyle value({PdfColor? color}) =>
      _s(size: scale.value, color: color ?? palette.text);
  pw.TextStyle valueBold({PdfColor? color}) =>
      _s(size: scale.value, bold: true, color: color ?? palette.text);
  pw.TextStyle tableHeader({PdfColor? color}) => _s(
        size: scale.tableHeader,
        bold: true,
        color: color ?? palette.text,
        letterSpacing: 0.1,
      );
  pw.TextStyle tableCell({PdfColor? color, bool bold = false}) =>
      _s(size: scale.tableCell, bold: bold, color: color ?? palette.text);
  pw.TextStyle groupHeader({PdfColor? color}) =>
      _s(size: scale.groupHeader, bold: true, color: color ?? palette.groupBandText);
  pw.TextStyle subtotal({PdfColor? color}) =>
      _s(size: scale.subtotal, bold: true, color: color ?? palette.text);
  pw.TextStyle grandTotal({PdfColor? color}) =>
      _s(size: scale.grandTotal, bold: true, color: color ?? palette.grandBandText);
  pw.TextStyle summaryTitle({PdfColor? color}) =>
      _s(size: scale.summaryTitle, bold: true, color: color ?? palette.text);
  pw.TextStyle summaryRowLabel() =>
      _s(size: scale.summaryRow, color: palette.textMuted);
  pw.TextStyle summaryRowValue({PdfColor? color, bool bold = false}) =>
      _s(size: scale.summaryRow, bold: bold, color: color ?? palette.text);
  pw.TextStyle summaryTotal({PdfColor? color}) =>
      _s(size: scale.summaryTotal, bold: true, color: color ?? palette.text);
  pw.TextStyle note() => _s(size: scale.note, color: palette.textMuted);
  pw.TextStyle footer() => _s(size: scale.footer, color: palette.textFaint);
  pw.TextStyle signature() =>
      _s(size: scale.signature, bold: true, color: palette.text);
  pw.TextStyle caption() => _s(size: scale.caption, color: palette.textFaint);
}
