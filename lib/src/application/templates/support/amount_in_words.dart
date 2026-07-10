// APPLICATION · templates · support · amount in words. Pure Dart.
//
// Converts a monetary amount to words in English or Arabic for cheques,
// vouchers and invoices. Round the amount with a GeniusRoundingPolicy BEFORE
// calling, so the words match the printed figure exactly.

/// Supported spelling languages.
enum AmountWordsLanguage { english, arabic }

/// Converts [amount] to words, e.g. 1035.50 SAR →
/// "One Thousand Thirty-Five Riyals and Fifty Halalas".
String amountInWords(
  double amount, {
  required String currencyCode,
  AmountWordsLanguage language = AmountWordsLanguage.english,
  int fractionDigits = 2,
}) {
  final negative = amount < 0;
  final factor = _pow10(fractionDigits);
  final totalMinor = (amount.abs() * factor).round();
  final whole = totalMinor ~/ factor;
  final frac = totalMinor % factor;

  final units = _currencyUnits[currencyCode.toUpperCase()] ??
      _CurrencyUnits(
        majorEn: currencyCode.toUpperCase(),
        majorEnPlural: currencyCode.toUpperCase(),
        minorEn: 'Cents',
        majorAr: currencyCode.toUpperCase(),
        minorAr: 'فلس',
      );

  if (language == AmountWordsLanguage.arabic) {
    final words = _arabicThreeScale(whole);
    final buf = StringBuffer(words.isEmpty ? 'صفر' : words);
    buf.write(' ${units.majorAr}');
    if (frac > 0 && fractionDigits > 0) {
      buf.write(' و ${_arabicThreeScale(frac)} ${units.minorAr}');
    }
    buf.write(' فقط لا غير');
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  final wholeWords = _englishThreeScale(whole);
  final buf = StringBuffer(negative ? 'Minus ' : '');
  buf.write(wholeWords.isEmpty ? 'Zero' : wholeWords);
  buf.write(' ${whole == 1 ? units.majorEn : units.majorEnPlural}');
  if (frac > 0 && fractionDigits > 0) {
    buf.write(' and ${_englishThreeScale(frac)} ${units.minorEn}');
  }
  buf.write(' Only');
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

class _CurrencyUnits {
  const _CurrencyUnits({
    required this.majorEn,
    required this.majorEnPlural,
    required this.minorEn,
    required this.majorAr,
    required this.minorAr,
  });
  final String majorEn;
  final String majorEnPlural;
  final String minorEn;
  final String majorAr;
  final String minorAr;
}

const Map<String, _CurrencyUnits> _currencyUnits = {
  'SAR': _CurrencyUnits(majorEn: 'Riyal', majorEnPlural: 'Riyals', minorEn: 'Halalas', majorAr: 'ريال سعودي', minorAr: 'هللة'),
  'AED': _CurrencyUnits(majorEn: 'Dirham', majorEnPlural: 'Dirhams', minorEn: 'Fils', majorAr: 'درهم إماراتي', minorAr: 'فلس'),
  'USD': _CurrencyUnits(majorEn: 'Dollar', majorEnPlural: 'Dollars', minorEn: 'Cents', majorAr: 'دولار', minorAr: 'سنت'),
  'EUR': _CurrencyUnits(majorEn: 'Euro', majorEnPlural: 'Euros', minorEn: 'Cents', majorAr: 'يورو', minorAr: 'سنت'),
  'GBP': _CurrencyUnits(majorEn: 'Pound', majorEnPlural: 'Pounds', minorEn: 'Pence', majorAr: 'جنيه', minorAr: 'بنس'),
  'KWD': _CurrencyUnits(majorEn: 'Dinar', majorEnPlural: 'Dinars', minorEn: 'Fils', majorAr: 'دينار كويتي', minorAr: 'فلس'),
  'EGP': _CurrencyUnits(majorEn: 'Pound', majorEnPlural: 'Pounds', minorEn: 'Piastres', majorAr: 'جنيه مصري', minorAr: 'قرش'),
};

// ── English ──

const _enOnes = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _enTens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
const _enScales = ['', 'Thousand', 'Million', 'Billion', 'Trillion'];

String _englishBelowThousand(int n) {
  final buf = <String>[];
  if (n >= 100) {
    buf.add('${_enOnes[n ~/ 100]} Hundred');
    n %= 100;
  }
  if (n >= 20) {
    final t = _enTens[n ~/ 10];
    final o = n % 10;
    buf.add(o > 0 ? '$t-${_enOnes[o]}' : t);
  } else if (n > 0) {
    buf.add(_enOnes[n]);
  }
  return buf.join(' ');
}

String _englishThreeScale(int n) {
  if (n == 0) return '';
  final groups = <int>[];
  var v = n;
  while (v > 0) {
    groups.add(v % 1000);
    v ~/= 1000;
  }
  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    if (groups[i] == 0) continue;
    final words = _englishBelowThousand(groups[i]);
    parts.add(i > 0 ? '$words ${_enScales[i]}' : words);
  }
  return parts.join(' ');
}

// ── Arabic (functional; standard forms without full case inflection) ──

const _arOnes = [
  '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة',
  'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر',
  'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];
const _arTens = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
const _arHundreds = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];
const _arScales = ['', 'ألف', 'مليون', 'مليار', 'تريليون'];

String _arabicBelowThousand(int n) {
  final buf = <String>[];
  if (n >= 100) {
    buf.add(_arHundreds[n ~/ 100]);
    n %= 100;
  }
  if (n >= 20) {
    final o = n % 10;
    final t = _arTens[n ~/ 10];
    buf.add(o > 0 ? '${_arOnes[o]} و$t' : t);
  } else if (n > 0) {
    buf.add(_arOnes[n]);
  }
  return buf.join(' و');
}

String _arabicThreeScale(int n) {
  if (n == 0) return '';
  final groups = <int>[];
  var v = n;
  while (v > 0) {
    groups.add(v % 1000);
    v ~/= 1000;
  }
  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    if (groups[i] == 0) continue;
    final words = _arabicBelowThousand(groups[i]);
    if (i == 0) {
      parts.add(words);
    } else if (groups[i] == 1) {
      parts.add(_arScales[i]);
    } else if (groups[i] == 2) {
      parts.add('${_arScales[i]}ان');
    } else {
      parts.add('$words ${_arScales[i]}');
    }
  }
  return parts.join(' و');
}
