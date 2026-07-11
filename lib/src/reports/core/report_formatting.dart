import '../core/report_direction.dart';

/// Locale-light number, currency and date formatting for the reports. Kept
/// dependency-free (no `intl`) and direction-aware: the reference documents
/// place the currency code *after* the amount in LTR (`30,100.00 SAR`) and
/// *before* it in RTL (`SAR 30,100.00`).
class ReportFormat {
  const ReportFormat({
    this.currencyCode = 'SAR',
    this.decimals = 2,
    this.groupSep = ',',
    this.decimalSep = '.',
    this.datePattern = 'dd/MM/yyyy',
  });

  final String currencyCode;
  final int decimals;
  final String groupSep;
  final String decimalSep;
  final String datePattern;

  ReportFormat copyWith({String? currencyCode, int? decimals}) => ReportFormat(
        currencyCode: currencyCode ?? this.currencyCode,
        decimals: decimals ?? this.decimals,
        groupSep: groupSep,
        decimalSep: decimalSep,
        datePattern: datePattern,
      );

  /// Groups thousands and fixes decimals. No currency symbol.
  String number(num value, {int? decimals}) {
    final dp = decimals ?? this.decimals;
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(dp);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(groupSep);
      buf.write(intPart[i]);
    }
    var out = buf.toString();
    if (dp > 0) out = '$out$decimalSep${parts[1]}';
    return negative ? '-$out' : out;
  }

  /// A money amount with the currency code placed per [dir]:
  /// `30,100.00 SAR` (LTR) or `SAR 30,100.00` (RTL).
  String money(num value, ReportDir dir, {String? code, int? decimals}) {
    final c = code ?? currencyCode;
    final n = number(value, decimals: decimals);
    return dir.isRtl ? '$c $n' : '$n $c';
  }

  /// A signed deduction amount, e.g. `- SAR 1,000.00` / `- 1,000.00 SAR`.
  String deduction(num value, ReportDir dir, {String? code, int? decimals}) =>
      '- ${money(value.abs(), dir, code: code, decimals: decimals)}';

  /// `dd/MM/yyyy` by default.
  String date(DateTime d) => _apply(datePattern, d);

  /// `dd/MM/yyyy HH:mm` — used by the "Printed:" line.
  String dateTime(DateTime d) => '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';

  String _apply(String pattern, DateTime d) => pattern
      .replaceAll('yyyy', d.year.toString().padLeft(4, '0'))
      .replaceAll('MM', _two(d.month))
      .replaceAll('dd', _two(d.day));

  static String _two(int n) => n.toString().padLeft(2, '0');
}
