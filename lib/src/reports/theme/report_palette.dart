import 'package:pdf/pdf.dart';

/// The muted print palette shared by every GeniusLink report PDF.
///
/// These are the exact fills recovered from the reference documents: a mostly
/// grayscale system (header bars, zebra rows, total bands) lifted with a few
/// semantic tints — a light blue group band, green for positive subtotals, red
/// for deductions and a neutral gray for grand totals.
class ReportPalette {
  const ReportPalette({
    this.text = const PdfColor.fromInt(0xff1f2937),
    this.textMuted = const PdfColor.fromInt(0xff5b6472),
    this.textFaint = const PdfColor.fromInt(0xff9097a3),
    this.page = const PdfColor.fromInt(0xffffffff),
    this.rule = const PdfColor.fromInt(0xff333333),
    this.border = const PdfColor.fromInt(0xffcccccc),
    this.borderSoft = const PdfColor.fromInt(0xffe0e0e0),
    this.tableHeader = const PdfColor.fromInt(0xffe0e0e0),
    this.boxHeader = const PdfColor.fromInt(0xffe8e8e8),
    this.zebra = const PdfColor.fromInt(0xfff5f5f5),
    this.groupBand = const PdfColor.fromInt(0xffe3f2fd),
    this.groupBandText = const PdfColor.fromInt(0xff0d47a1),
    this.totalBand = const PdfColor.fromInt(0xffe8e8e8),
    this.grandBand = const PdfColor.fromInt(0xff424242),
    this.grandBandText = const PdfColor.fromInt(0xffffffff),
    this.surface = const PdfColor.fromInt(0xfff8f9fa),
    this.surfaceAlt = const PdfColor.fromInt(0xfffafafa),
    this.surfaceHeader = const PdfColor.fromInt(0xffe9ecef),
    this.positive = const PdfColor.fromInt(0xffe8f5e9),
    this.positiveText = const PdfColor.fromInt(0xff1b5e20),
    this.negative = const PdfColor.fromInt(0xffffebee),
    this.negativeText = const PdfColor.fromInt(0xffb71c1c),
    this.accent = const PdfColor.fromInt(0xff1565c0),
    this.saudiGreen = const PdfColor.fromInt(0xff1b5e20),
  });

  /// Primary body text (near-black slate).
  final PdfColor text;

  /// Secondary labels and captions.
  final PdfColor textMuted;

  /// Faint hints (printed-on line, footer chrome).
  final PdfColor textFaint;

  /// Page background.
  final PdfColor page;

  /// The strong hairline drawn under the company header.
  final PdfColor rule;

  /// Default table / box border.
  final PdfColor border;

  /// A lighter internal separator.
  final PdfColor borderSoft;

  /// Table header cell fill (`#e0e0e0`).
  final PdfColor tableHeader;

  /// Info-box header bar fill (`#e8e8e8`).
  final PdfColor boxHeader;

  /// Alternating (zebra) table row fill (`#f5f5f5`).
  final PdfColor zebra;

  /// Category / group band fill (`#e3f2fd`) + its text color.
  final PdfColor groupBand;
  final PdfColor groupBandText;

  /// Emphasised total row fill (`#e8e8e8`).
  final PdfColor totalBand;

  /// Grand-total dark band (`#424242`) + its text color.
  final PdfColor grandBand;
  final PdfColor grandBandText;

  /// Summary-box surface fill (`#f8f9fa`).
  final PdfColor surface;

  /// Card-style summary surface (`#fafafa`).
  final PdfColor surfaceAlt;

  /// Summary-box title-bar fill (`#e9ecef`).
  final PdfColor surfaceHeader;

  /// Positive / subtotal tint (`#e8f5e9`) + its text color.
  final PdfColor positive;
  final PdfColor positiveText;

  /// Deduction / negative tint (`#ffebee`) + its text color.
  final PdfColor negative;
  final PdfColor negativeText;

  /// Brand accent (used for group titles, links).
  final PdfColor accent;

  /// Saudi-official green (optional header theme).
  final PdfColor saudiGreen;

  static const ReportPalette standard = ReportPalette();
}
