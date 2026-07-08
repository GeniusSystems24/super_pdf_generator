// SHARED · GeniusLink design tokens for Folio Studio.
//
// A faithful Dart port of the GeniusLink CSS token set: dark-first surfaces,
// the single electric-royal-blue accent, semantic status colors, 4px spacing
// scale and the Manrope / Inter / JetBrains Mono type roles. Exposed as a
// ThemeExtension so widgets read `context.gl`.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class GlColors extends ThemeExtension<GlColors> {
  const GlColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.input,
    required this.hover,
    required this.border,
    required this.borderStrong,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fg4,
    required this.accent,
    required this.green,
    required this.orange,
    required this.danger,
    required this.shadow,
  });

  final Color bg, surface, surface2, input, hover, border, borderStrong;
  final Color fg1, fg2, fg3, fg4;
  final Color accent, green, orange, danger;
  final Color shadow;

  /// Dark is the default GeniusLink theme.
  static const GlColors dark = GlColors(
    bg: Color(0xFF111318),
    surface: Color(0xFF1E2025),
    surface2: Color(0xFF292D38),
    input: Color(0xFF33353A),
    hover: Color(0xFF2F3540),
    border: Color(0x66434654),
    borderStrong: Color(0xFF434654),
    fg1: Color(0xFFE2E2E9),
    fg2: Color(0xFFC3C6D7),
    fg3: Color(0xFF8D90A0),
    fg4: Color(0xFF44474E),
    accent: Color(0xFF4A7CFF),
    green: Color(0xFF1DB88A),
    orange: Color(0xFFF97316),
    danger: Color(0xFFEF4444),
    shadow: Color(0x40000000),
  );

  static const GlColors light = GlColors(
    bg: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF7F8FA),
    input: Color(0xFFF1F3F8),
    hover: Color(0xFFEEF1F7),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFC2C6D6),
    fg1: Color(0xFF0F172A),
    fg2: Color(0xFF424754),
    fg3: Color(0xFF64748B),
    fg4: Color(0xFFC2C6D6),
    accent: Color(0xFF4A7CFF),
    green: Color(0xFF1DB88A),
    orange: Color(0xFFF97316),
    danger: Color(0xFFEF4444),
    shadow: Color(0x14000000),
  );

  @override
  GlColors copyWith({
    Color? bg, Color? surface, Color? surface2, Color? input, Color? hover,
    Color? border, Color? borderStrong, Color? fg1, Color? fg2, Color? fg3,
    Color? fg4, Color? accent, Color? green, Color? orange, Color? danger,
    Color? shadow,
  }) {
    return GlColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      input: input ?? this.input,
      hover: hover ?? this.hover,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      fg1: fg1 ?? this.fg1,
      fg2: fg2 ?? this.fg2,
      fg3: fg3 ?? this.fg3,
      fg4: fg4 ?? this.fg4,
      accent: accent ?? this.accent,
      green: green ?? this.green,
      orange: orange ?? this.orange,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  GlColors lerp(ThemeExtension<GlColors>? other, double t) {
    if (other is! GlColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// 4px spacing scale.
abstract final class GlSpace {
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 24, s6 = 32, s7 = 40;
}

/// Radii.
abstract final class GlRadius {
  static const Radius sm = Radius.circular(4);
  static const Radius md = Radius.circular(6);
  static const Radius lg = Radius.circular(8);
  static const Radius xl = Radius.circular(12);
  static const BorderRadius card = BorderRadius.all(lg);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

extension GlContext on BuildContext {
  GlColors get gl => Theme.of(this).extension<GlColors>() ?? GlColors.dark;
}

/// Type roles. Manrope = display, Inter = body, JetBrains Mono = numerics.
abstract final class GlType {
  static TextStyle display(BuildContext c,
          {double size = 26, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.manrope(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -0.5,
          color: c.gl.fg1);

  static TextStyle body(BuildContext c,
          {double size = 14,
          FontWeight weight = FontWeight.w400,
          Color? color}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? c.gl.fg2);

  static TextStyle label(BuildContext c, {Color? color}) => GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color ?? c.gl.fg3);

  static TextStyle mono(BuildContext c,
          {double size = 12, Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, fontWeight: weight, color: color ?? c.gl.fg2);
}
