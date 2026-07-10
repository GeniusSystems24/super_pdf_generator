// DOMAIN · financial · money value object. Pure Dart (only dart:math).
//
// An immutable monetary value stored as an integer count of minor currency
// units, so all arithmetic is exact. Multiplication by a rate rounds exactly
// once, using a [GeniusRoundingPolicy].

import 'dart:math';

import 'genius_rounding_policy.dart';

/// An immutable monetary value stored as an integer count of minor currency units.
///
/// ## Example
/// ```dart
/// final policy = GeniusRoundingPolicy.defaults();
/// final subtotal = GeniusMoney.fromDouble(900.00, currency: 'SAR', policy: policy);
/// final vat = subtotal.multiplyByRate(0.15, policy: policy); // 135.00
/// final grand = subtotal + vat;                              // 1035.00
/// ```
class GeniusMoney {
  const GeniusMoney.fromMinorUnits(
    this.minorUnits, {
    required this.currency,
    this.decimalPlaces = 2,
  });

  /// Converts [value] to minor units using [policy] rounding (rounds once).
  factory GeniusMoney.fromDouble(
    double value, {
    String currency = 'SAR',
    GeniusRoundingPolicy? policy,
  }) {
    final p = policy ?? GeniusRoundingPolicy.defaults();
    final rounded = p.round(value);
    final factor = pow(10, p.decimalPlaces);
    return GeniusMoney.fromMinorUnits(
      (rounded * factor).round(),
      currency: currency,
      decimalPlaces: p.decimalPlaces,
    );
  }

  factory GeniusMoney.zero({String currency = 'SAR', int decimalPlaces = 2}) =>
      GeniusMoney.fromMinorUnits(0,
          currency: currency, decimalPlaces: decimalPlaces,);

  final int minorUnits;
  final String currency;
  final int decimalPlaces;

  // ── Arithmetic ──

  /// Exact integer addition. Currencies must match.
  GeniusMoney operator +(GeniusMoney other) {
    assert(
      currency == other.currency,
      'Cannot add $currency and ${other.currency}',
    );
    return GeniusMoney.fromMinorUnits(
      minorUnits + other.minorUnits,
      currency: currency,
      decimalPlaces: decimalPlaces,
    );
  }

  /// Exact integer subtraction. Currencies must match.
  GeniusMoney operator -(GeniusMoney other) {
    assert(
      currency == other.currency,
      'Cannot subtract ${other.currency} from $currency',
    );
    return GeniusMoney.fromMinorUnits(
      minorUnits - other.minorUnits,
      currency: currency,
      decimalPlaces: decimalPlaces,
    );
  }

  /// Multiplies this amount by [rate] and rounds the result once using [policy].
  GeniusMoney multiplyByRate(double rate, {GeniusRoundingPolicy? policy}) {
    final p = policy ?? GeniusRoundingPolicy(decimalPlaces: decimalPlaces);
    final rawAmount = toDouble() * rate;
    final roundedAmount = p.round(rawAmount);
    final factor = pow(10, decimalPlaces);
    return GeniusMoney.fromMinorUnits(
      (roundedAmount * factor).round(),
      currency: currency,
      decimalPlaces: decimalPlaces,
    );
  }

  /// Alias for [multiplyByRate].
  GeniusMoney multiplyByDouble(double value, {GeniusRoundingPolicy? policy}) =>
      multiplyByRate(value, policy: policy);

  // ── Comparison ──

  @override
  bool operator ==(Object other) =>
      other is GeniusMoney &&
      minorUnits == other.minorUnits &&
      currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  int compareTo(GeniusMoney other) => minorUnits.compareTo(other.minorUnits);

  /// Compares using integer minor-unit arithmetic to avoid IEEE 754 boundary issues.
  bool isWithinTolerance(GeniusMoney other, GeniusRoundingPolicy policy) {
    final diffUnits = (minorUnits - other.minorUnits).abs();
    final factor = pow(10, decimalPlaces);
    final absD = (policy.absoluteTolerance ?? (1.0 / factor)) * factor;
    final absLimitUnits = (absD + 0.5).floor();
    if (policy.relativeTolerance == null) return diffUnits <= absLimitUnits;
    final relLimitUnits = (policy.relativeTolerance! * minorUnits.abs()).round();
    final limitUnits =
        absLimitUnits > relLimitUnits ? absLimitUnits : relLimitUnits;
    return diffUnits <= limitUnits;
  }

  // ── Conversion ──

  double toDouble() => minorUnits / pow(10, decimalPlaces);

  String toDisplayString({int? decimalPlaces}) =>
      toDouble().toStringAsFixed(decimalPlaces ?? this.decimalPlaces);

  @override
  String toString() => '${toDisplayString()} $currency';
}
