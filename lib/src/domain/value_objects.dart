// DOMAIN · value objects. Pure Dart, immutable, serializable. These are the
// primitive units the document model is built from. Kept free of Flutter so
// that a full document definition can be sent across an isolate boundary.

import 'package:meta/meta.dart';

/// Page reading direction. RTL is a first-class concern (Arabic support).
enum PdfDirection { ltr, rtl }

/// Text alignment, expressed with logical start/end so it mirrors under RTL.
enum PdfAlign { start, center, end, justify }

/// Page orientation.
enum PdfPageOrientation { portrait, landscape }

/// Coarse font weight tokens (mapped to concrete weights by the renderer).
enum PdfFontWeightToken { regular, medium, semiBold, bold }

/// An immutable ARGB color, independent of `dart:ui`.
@immutable
class PdfColor {
  const PdfColor(this.argb);

  factory PdfColor.rgb(int r, int g, int b, [int a = 0xFF]) =>
      PdfColor((a << 24) | (r << 16) | (g << 8) | b);

  /// Parse `#RGB`, `#RRGGBB` or `#AARRGGBB`.
  factory PdfColor.hex(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length == 6) {
      h = 'FF$h';
    }
    final value = int.tryParse(h, radix: 16) ?? 0xFF000000;
    return PdfColor(value);
  }

  final int argb;

  int get alpha => (argb >> 24) & 0xFF;
  int get red => (argb >> 16) & 0xFF;
  int get green => (argb >> 8) & 0xFF;
  int get blue => argb & 0xFF;

  String toHex() {
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#$rgb';
  }

  Map<String, Object?> toJson() => <String, Object?>{'argb': argb};

  factory PdfColor.fromJson(Map<String, Object?> json) =>
      PdfColor((json['argb'] as num?)?.toInt() ?? 0xFF000000);

  @override
  bool operator ==(Object other) => other is PdfColor && other.argb == argb;

  @override
  int get hashCode => argb.hashCode;

  static const PdfColor ink = PdfColor(0xFF111318);
  static const PdfColor muted = PdfColor(0xFF6B7280);
  static const PdfColor accent = PdfColor(0xFF2A6FDB);
  static const PdfColor surface = PdfColor(0xFFF3F4F6);
  static const PdfColor positive = PdfColor(0xFF1F8A5B);
}

/// A physical page size in PostScript points (1/72 inch).
@immutable
class PdfPageSize {
  const PdfPageSize(this.name, this.widthPt, this.heightPt);

  final String name;
  final double widthPt;
  final double heightPt;

  static const PdfPageSize a3 = PdfPageSize('A3', 841.89, 1190.55);
  static const PdfPageSize a4 = PdfPageSize('A4', 595.28, 841.89);
  static const PdfPageSize a5 = PdfPageSize('A5', 419.53, 595.28);
  static const PdfPageSize letter = PdfPageSize('Letter', 612, 792);
  static const PdfPageSize legal = PdfPageSize('Legal', 612, 1008);

  static const List<PdfPageSize> presets = <PdfPageSize>[a3, a4, a5, letter, legal];

  static PdfPageSize byName(String name) => presets.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
        orElse: () => a4,
      );

  /// This size rotated for the given [orientation].
  PdfPageSize oriented(PdfPageOrientation orientation) {
    final isLandscape = orientation == PdfPageOrientation.landscape;
    final w = isLandscape
        ? (widthPt > heightPt ? widthPt : heightPt)
        : (widthPt < heightPt ? widthPt : heightPt);
    final h = isLandscape
        ? (widthPt > heightPt ? heightPt : widthPt)
        : (widthPt < heightPt ? heightPt : widthPt);
    return PdfPageSize(name, w, h);
  }

  Map<String, Object?> toJson() =>
      <String, Object?>{'name': name, 'w': widthPt, 'h': heightPt};

  factory PdfPageSize.fromJson(Map<String, Object?> json) => PdfPageSize(
        (json['name'] as String?) ?? 'A4',
        (json['w'] as num?)?.toDouble() ?? a4.widthPt,
        (json['h'] as num?)?.toDouble() ?? a4.heightPt,
      );

  @override
  bool operator ==(Object other) =>
      other is PdfPageSize &&
      other.name == name &&
      other.widthPt == widthPt &&
      other.heightPt == heightPt;

  @override
  int get hashCode => Object.hash(name, widthPt, heightPt);
}

/// Immutable page margins in points.
@immutable
class PdfMargins {
  const PdfMargins.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  const PdfMargins.all(double value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const PdfMargins.symmetric({double horizontal = 0, double vertical = 0})
      : left = horizontal,
        right = horizontal,
        top = vertical,
        bottom = vertical;

  final double left;
  final double top;
  final double right;
  final double bottom;

  Map<String, Object?> toJson() => <String, Object?>{
        'l': left,
        't': top,
        'r': right,
        'b': bottom,
      };

  factory PdfMargins.fromJson(Map<String, Object?> json) => PdfMargins.only(
        left: (json['l'] as num?)?.toDouble() ?? 0,
        top: (json['t'] as num?)?.toDouble() ?? 0,
        right: (json['r'] as num?)?.toDouble() ?? 0,
        bottom: (json['b'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is PdfMargins &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Parse an enum by name with a fallback.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
