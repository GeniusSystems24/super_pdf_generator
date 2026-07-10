// DOMAIN · theme & typography. Pure, immutable, serializable.
//
// The PdfTheme is the *document* theme — entirely independent of the Flutter
// UI theme used by the demo app (mirrors the Web proposal's dual-token system).

import 'package:meta/meta.dart';

import 'value_objects.dart';

/// A registered font, referenced by [family]. Actual byte loading is performed
/// by an infrastructure [FontRegistry]; the domain only names the font.
@immutable
class PdfFont {
  const PdfFont({
    required this.family,
    this.weight = PdfFontWeightToken.regular,
    this.italic = false,
    this.assetKey,
  });

  final String family;
  final PdfFontWeightToken weight;
  final bool italic;

  /// Optional key an infrastructure registry uses to locate font bytes.
  final String? assetKey;

  Map<String, Object?> toJson() => <String, Object?>{
        'family': family,
        'weight': weight.name,
        'italic': italic,
        'assetKey': assetKey,
      };

  factory PdfFont.fromJson(Map<String, Object?> json) => PdfFont(
        family: (json['family'] as String?) ?? 'Helvetica',
        weight: enumByName(
          PdfFontWeightToken.values,
          json['weight'],
          PdfFontWeightToken.regular,
        ),
        italic: (json['italic'] as bool?) ?? false,
        assetKey: json['assetKey'] as String?,
      );
}

/// An immutable text style token.
@immutable
class PdfTextStyle {
  const PdfTextStyle({
    this.fontFamily,
    this.fontSize = 11,
    this.weight = PdfFontWeightToken.regular,
    this.color = PdfColor.ink,
    this.lineHeight = 1.45,
    this.align = PdfAlign.start,
    this.italic = false,
    this.letterSpacing = 0,
  });

  final String? fontFamily;
  final double fontSize;
  final PdfFontWeightToken weight;
  final PdfColor color;
  final double lineHeight;
  final PdfAlign align;
  final bool italic;
  final double letterSpacing;

  PdfTextStyle copyWith({
    String? fontFamily,
    double? fontSize,
    PdfFontWeightToken? weight,
    PdfColor? color,
    double? lineHeight,
    PdfAlign? align,
    bool? italic,
    double? letterSpacing,
  }) =>
      PdfTextStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        weight: weight ?? this.weight,
        color: color ?? this.color,
        lineHeight: lineHeight ?? this.lineHeight,
        align: align ?? this.align,
        italic: italic ?? this.italic,
        letterSpacing: letterSpacing ?? this.letterSpacing,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'weight': weight.name,
        'color': color.toJson(),
        'lineHeight': lineHeight,
        'align': align.name,
        'italic': italic,
        'letterSpacing': letterSpacing,
      };

  factory PdfTextStyle.fromJson(Map<String, Object?> json) => PdfTextStyle(
        fontFamily: json['fontFamily'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 11,
        weight: enumByName(
          PdfFontWeightToken.values,
          json['weight'],
          PdfFontWeightToken.regular,
        ),
        color: json['color'] is Map
            ? PdfColor.fromJson((json['color']! as Map).cast<String, Object?>())
            : PdfColor.ink,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.45,
        align: enumByName(PdfAlign.values, json['align'], PdfAlign.start),
        italic: (json['italic'] as bool?) ?? false,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
      );
}

/// Palette used by the document renderer.
@immutable
class PdfPalette {
  const PdfPalette({
    this.ink = PdfColor.ink,
    this.muted = PdfColor.muted,
    this.accent = PdfColor.accent,
    this.surface = PdfColor.surface,
    this.positive = PdfColor.positive,
  });

  final PdfColor ink;
  final PdfColor muted;
  final PdfColor accent;
  final PdfColor surface;
  final PdfColor positive;

  PdfPalette copyWith({PdfColor? accent}) =>
      PdfPalette(ink: ink, muted: muted, accent: accent ?? this.accent, surface: surface, positive: positive);

  Map<String, Object?> toJson() => <String, Object?>{
        'ink': ink.toJson(),
        'muted': muted.toJson(),
        'accent': accent.toJson(),
        'surface': surface.toJson(),
        'positive': positive.toJson(),
      };

  factory PdfPalette.fromJson(Map<String, Object?> json) {
    PdfColor pick(String k, PdfColor d) => json[k] is Map
        ? PdfColor.fromJson((json[k]! as Map).cast<String, Object?>())
        : d;
    return PdfPalette(
      ink: pick('ink', PdfColor.ink),
      muted: pick('muted', PdfColor.muted),
      accent: pick('accent', PdfColor.accent),
      surface: pick('surface', PdfColor.surface),
      positive: pick('positive', PdfColor.positive),
    );
  }
}

/// The document theme. Runtime document tokens — distinct from the demo app's
/// Flutter UI theme.
@immutable
class PdfTheme {
  const PdfTheme({
    this.palette = const PdfPalette(),
    this.baseFontFamily,
    this.arabicFontFamily,
    this.monoFontFamily,
    this.spacing = const <double>[4, 8, 12, 16, 24, 32],
    this.radius = 4,
    this.direction = PdfDirection.ltr,
    this.variant = 'light',
  });

  final PdfPalette palette;
  final String? baseFontFamily;
  final String? arabicFontFamily;
  final String? monoFontFamily;
  final List<double> spacing;
  final double radius;
  final PdfDirection direction;

  /// One of: `light`, `dark`, `branded`, `rtl`, `compact`, `print`.
  final String variant;

  PdfTheme copyWith({
    PdfPalette? palette,
    PdfDirection? direction,
    String? variant,
    String? baseFontFamily,
    String? arabicFontFamily,
  }) =>
      PdfTheme(
        palette: palette ?? this.palette,
        baseFontFamily: baseFontFamily ?? this.baseFontFamily,
        arabicFontFamily: arabicFontFamily ?? this.arabicFontFamily,
        monoFontFamily: monoFontFamily,
        spacing: spacing,
        radius: radius,
        direction: direction ?? this.direction,
        variant: variant ?? this.variant,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'palette': palette.toJson(),
        'baseFontFamily': baseFontFamily,
        'arabicFontFamily': arabicFontFamily,
        'monoFontFamily': monoFontFamily,
        'spacing': spacing,
        'radius': radius,
        'direction': direction.name,
        'variant': variant,
      };

  factory PdfTheme.fromJson(Map<String, Object?> json) => PdfTheme(
        palette: json['palette'] is Map
            ? PdfPalette.fromJson(
                (json['palette']! as Map).cast<String, Object?>(),)
            : const PdfPalette(),
        baseFontFamily: json['baseFontFamily'] as String?,
        arabicFontFamily: json['arabicFontFamily'] as String?,
        monoFontFamily: json['monoFontFamily'] as String?,
        spacing: (json['spacing'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const <double>[4, 8, 12, 16, 24, 32],
        radius: (json['radius'] as num?)?.toDouble() ?? 4,
        direction:
            enumByName(PdfDirection.values, json['direction'], PdfDirection.ltr),
        variant: (json['variant'] as String?) ?? 'light',
      );

  static const PdfTheme light = PdfTheme();
  static const PdfTheme rtl = PdfTheme(direction: PdfDirection.rtl, variant: 'rtl');
}
