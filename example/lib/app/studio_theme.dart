import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/gl_tokens.dart';

/// Builds the Studio [ThemeData] for each brightness from the GeniusLink
/// tokens. This is the demo app's UI theme — entirely separate from the
/// document `PdfTheme` the library renders into the PDF.
abstract final class StudioTheme {
  static ThemeData dark() => _build(GlColors.dark, Brightness.dark);
  static ThemeData light() => _build(GlColors.light, Brightness.light);

  static ThemeData _build(GlColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(surface: c.surface, primary: c.accent, error: c.danger),
      dividerColor: c.border,
      textTheme: GoogleFonts.interTextTheme(base.textTheme)
          .apply(bodyColor: c.fg1, displayColor: c.fg1),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
