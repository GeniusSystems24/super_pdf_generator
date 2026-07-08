// DOMAIN · financial · rounding policy. Pure Dart (only dart:math).
//
// Adopted into Folio's domain layer from the GeniusLink PDF reference. Defines
// how computed monetary values are rounded to minor units and the tolerance
// used when validating provided totals against recomputed ones.

import 'dart:math';

/// Rounding mode applied when converting a computed value to minor units.
enum GeniusRoundingMode {
  halfUp,
  halfEven,
  truncate,
  floor,
  ceiling,
}

/// Configuration for how monetary amounts are rounded and validated.
///
/// Tolerance check: |expected − actual| ≤ max(absoluteTolerance, relativeTolerance × |expected|).
/// When [relativeTolerance] is null, only the absolute bound applies.
/// When [absoluteTolerance] is null, defaults to one minor unit (10^-decimalPlaces).
class GeniusRoundingPolicy {
  const GeniusRoundingPolicy({
    this.decimalPlaces = 2,
    this.mode = GeniusRoundingMode.halfUp,
    this.absoluteTolerance,
    this.relativeTolerance,
  });

  factory GeniusRoundingPolicy.defaults() => const GeniusRoundingPolicy();

  factory GeniusRoundingPolicy.strict() =>
      const GeniusRoundingPolicy(absoluteTolerance: 0.0);

  factory GeniusRoundingPolicy.forCurrency(String currencyCode) {
    final dp = _currencyDecimalPlaces[currencyCode.toUpperCase()] ?? 2;
    return GeniusRoundingPolicy(decimalPlaces: dp);
  }

  factory GeniusRoundingPolicy.withRelative(double fractionTolerance) =>
      GeniusRoundingPolicy(relativeTolerance: fractionTolerance);

  final int decimalPlaces;
  final GeniusRoundingMode mode;

  /// Fixed monetary tolerance. Null → 1 minor unit (e.g. 0.01 for 2dp).
  final double? absoluteTolerance;

  /// Fractional tolerance (e.g. 0.001 = 0.1%). Null → disabled.
  final double? relativeTolerance;

  static const Map<String, int> _currencyDecimalPlaces = {
    'KWD': 3,
    'BHD': 3,
    'OMR': 3,
    'JOD': 3,
    'JPY': 0,
    'KRW': 0,
    'VND': 0,
    'IDR': 0,
  };

  /// Rounds [value] to [decimalPlaces] decimal places using [mode].
  double round(double value) {
    final factor = pow(10, decimalPlaces).toDouble();
    final scaled = value * factor;
    final rounded = _applyMode(scaled);
    return rounded / factor;
  }

  /// Returns true if |expected − actual| ≤ the effective tolerance.
  bool isWithinTolerance(double expected, double actual) {
    final diff = (expected - actual).abs();
    final minorUnit = pow(10.0, -decimalPlaces);
    final absLimit = absoluteTolerance ?? minorUnit;
    if (relativeTolerance == null) return diff <= absLimit;
    final relLimit = relativeTolerance! * expected.abs();
    return diff <= (absLimit > relLimit ? absLimit : relLimit);
  }

  double _applyMode(double scaled) {
    switch (mode) {
      case GeniusRoundingMode.halfUp:
        if (scaled >= 0) return (scaled + 0.5).floor().toDouble();
        return -((-scaled + 0.5).floor().toDouble());
      case GeniusRoundingMode.halfEven:
        final floorVal = scaled.floor();
        final diff = scaled - floorVal;
        if (diff < 0.5) return floorVal.toDouble();
        if (diff > 0.5) return (floorVal + 1).toDouble();
        return floorVal.isEven ? floorVal.toDouble() : (floorVal + 1).toDouble();
      case GeniusRoundingMode.truncate:
        return scaled.truncate().toDouble();
      case GeniusRoundingMode.floor:
        return scaled.floor().toDouble();
      case GeniusRoundingMode.ceiling:
        return scaled.ceil().toDouble();
    }
  }
}
