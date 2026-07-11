import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:pdf/widgets.dart' as pw;

/// Loads and holds the TrueType faces the reports render with.
///
/// The faces ship inside this package (`assets/fonts/`), so a consumer never
/// has to supply their own — Arabic shaping works out of the box. Call
/// [ReportFonts.load] once (keep the result around; it is cheap to reuse) and
/// hand the instance to [GeniusReports] or any document builder.
class ReportFonts {
  const ReportFonts({
    required this.latinRegular,
    required this.latinBold,
    required this.arabicRegular,
    required this.arabicBold,
  });

  /// Latin (Noto Sans) regular + bold.
  final pw.Font latinRegular;
  final pw.Font latinBold;

  /// Arabic (Noto Naskh Arabic) regular + bold.
  final pw.Font arabicRegular;
  final pw.Font arabicBold;

  static const String _pkg = 'packages/super_pdf_generator/assets/fonts';

  /// Loads the bundled faces from the package assets.
  static Future<ReportFonts> load() async {
    Future<pw.Font> f(String name) async {
      final ByteData data = await rootBundle.load('$_pkg/$name');
      return pw.Font.ttf(data);
    }

    final results = await Future.wait<pw.Font>([
      f('NotoSans-Regular.ttf'),
      f('NotoSans-Bold.ttf'),
      f('NotoNaskhArabic-Regular.ttf'),
      f('NotoNaskhArabic-Bold.ttf'),
    ]);

    return ReportFonts(
      latinRegular: results[0],
      latinBold: results[1],
      arabicRegular: results[2],
      arabicBold: results[3],
    );
  }

  /// Builds from already-decoded faces (e.g. custom brand fonts).
  factory ReportFonts.fromFonts({
    required pw.Font latinRegular,
    required pw.Font latinBold,
    required pw.Font arabicRegular,
    required pw.Font arabicBold,
  }) =>
      ReportFonts(
        latinRegular: latinRegular,
        latinBold: latinBold,
        arabicRegular: arabicRegular,
        arabicBold: arabicBold,
      );

  /// Regular fallbacks so mixed Latin/Arabic runs always resolve a glyph.
  List<pw.Font> get regularFallback => [arabicRegular, latinRegular];

  /// Bold fallbacks.
  List<pw.Font> get boldFallback => [arabicBold, latinBold];
}
