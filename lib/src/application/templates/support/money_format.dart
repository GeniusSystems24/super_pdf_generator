// APPLICATION · templates · support · money formatting. Pure Dart.
//
// Locale-light currency/number formatting for business templates. Kept
// dependency-free (no intl) so it is safe inside the framework-independent
// application layer. Groups thousands, fixes decimals to the currency's minor
// units and places the symbol per locale convention.

import '../../../domain/financial/genius_money.dart';

/// A minimal currency descriptor used by [formatMoney].
class CurrencyFormat {
  const CurrencyFormat({
    required this.code,
    required this.symbol,
    this.decimalPlaces = 2,
    this.symbolBefore = true,
    this.symbolSpace = true,
  });

  final String code;
  final String symbol;
  final int decimalPlaces;
  final bool symbolBefore;
  final bool symbolSpace;

  /// Built-in descriptors for the currencies the templates commonly use.
  static const Map<String, CurrencyFormat> _known = {
    'SAR': CurrencyFormat(code: 'SAR', symbol: 'SAR', decimalPlaces: 2, symbolBefore: false),
    'AED': CurrencyFormat(code: 'AED', symbol: 'AED', decimalPlaces: 2, symbolBefore: false),
    'USD': CurrencyFormat(code: 'USD', symbol: '\$', decimalPlaces: 2),
    'EUR': CurrencyFormat(code: 'EUR', symbol: '€', decimalPlaces: 2),
    'GBP': CurrencyFormat(code: 'GBP', symbol: '£', decimalPlaces: 2),
    'KWD': CurrencyFormat(code: 'KWD', symbol: 'KWD', decimalPlaces: 3, symbolBefore: false),
    'BHD': CurrencyFormat(code: 'BHD', symbol: 'BHD', decimalPlaces: 3, symbolBefore: false),
    'OMR': CurrencyFormat(code: 'OMR', symbol: 'OMR', decimalPlaces: 3, symbolBefore: false),
    'JOD': CurrencyFormat(code: 'JOD', symbol: 'JOD', decimalPlaces: 3, symbolBefore: false),
    'EGP': CurrencyFormat(code: 'EGP', symbol: 'EGP', decimalPlaces: 2, symbolBefore: false),
    'JPY': CurrencyFormat(code: 'JPY', symbol: '¥', decimalPlaces: 0),
  };

  static CurrencyFormat forCode(String code) =>
      _known[code.toUpperCase()] ??
      CurrencyFormat(code: code.toUpperCase(), symbol: code.toUpperCase(), symbolBefore: false);
}

/// Formats [value] with thousands grouping and fixed decimals.
String formatNumber(double value, {int decimalPlaces = 2, String groupSep = ',', String decimalSep = '.'}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimalPlaces);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(groupSep);
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (decimalPlaces > 0) out = '$out$decimalSep${parts[1]}';
  return negative ? '-$out' : out;
}

/// Formats a [GeniusMoney] as a display string with the currency symbol.
String formatMoney(GeniusMoney money, {CurrencyFormat? format}) {
  final f = format ?? CurrencyFormat.forCode(money.currency);
  final number = formatNumber(money.toDouble(), decimalPlaces: f.decimalPlaces);
  final space = f.symbolSpace ? ' ' : '';
  return f.symbolBefore ? '${f.symbol}$space$number' : '$number$space${f.symbol}';
}

/// Formats a raw double as currency for [code].
String formatAmount(double value, String code) {
  final f = CurrencyFormat.forCode(code);
  final number = formatNumber(value, decimalPlaces: f.decimalPlaces);
  final space = f.symbolSpace ? ' ' : '';
  return f.symbolBefore ? '${f.symbol}$space$number' : '$number$space${f.symbol}';
}
