// DOMAIN · financial · validator. Pure Dart.
//
// Stateless, audit-grade financial validator. Constructed with a
// [GeniusRoundingPolicy]; every method is a pure function of its arguments and
// returns a bilingual (EN/AR) [GeniusFinancialValidationResult]. Adopted from
// the GeniusLink PDF reference so business templates can prove their totals.

import 'genius_money.dart';
import 'genius_rounding_policy.dart';
import 'genius_validation_result.dart';

/// Stateless financial validator.
class GeniusFinancialValidator {
  const GeniusFinancialValidator(this.policy);

  final GeniusRoundingPolicy policy;

  GeniusMoney _m(double value) => GeniusMoney.fromDouble(value, policy: policy);

  bool _ok(GeniusMoney expected, GeniusMoney actual) =>
      expected.isWithinTolerance(actual, policy);

  /// Validates that sum of [lineTotals] ≈ [providedSubtotal].
  GeniusFinancialValidationResult validateSubtotal({
    required List<double> lineTotals,
    required double providedSubtotal,
  }) {
    final sum = lineTotals.fold(0.0, (s, v) => s + v);
    final expected = _m(sum);
    final actual = _m(providedSubtotal);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'subtotal',
        ruleId: 'subtotal_sum',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Subtotal (${actual.toDisplayString()}) does not match the sum of line totals (${expected.toDisplayString()})',
        messageAr:
            'الإجمالي الفرعي (${actual.toDisplayString()}) لا يتطابق مع مجموع بنود الفاتورة (${expected.toDisplayString()})',
      ),
    ]);
  }

  /// Validates that round([vatBase] × [vatRate]/100) ≈ [providedVatAmount].
  GeniusFinancialValidationResult validateVat({
    required double vatBase,
    required double vatRate,
    required double providedVatAmount,
  }) {
    final baseM = _m(vatBase);
    final expected = baseM.multiplyByRate(vatRate / 100, policy: policy);
    final actual = _m(providedVatAmount);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'vat_amount',
        ruleId: 'vat_calc',
        expectedValue: expected,
        actualValue: actual,
        message:
            'VAT amount (${actual.toDisplayString()}) does not match base × rate: '
            '${baseM.toDisplayString()} × $vatRate% = ${expected.toDisplayString()}',
        messageAr:
            'مبلغ ضريبة القيمة المضافة (${actual.toDisplayString()}) لا يتطابق مع '
            'الوعاء × المعدل: ${baseM.toDisplayString()} × $vatRate% = ${expected.toDisplayString()}',
      ),
    ]);
  }

  /// Validates that subtotal − discounts + vatAmount + fees ≈ [providedGrandTotal].
  GeniusFinancialValidationResult validateGrandTotal({
    required double subtotal,
    required double discounts,
    required double vatAmount,
    required double fees,
    required double providedGrandTotal,
  }) {
    final expected = _m(subtotal) - _m(discounts) + _m(vatAmount) + _m(fees);
    final actual = _m(providedGrandTotal);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'grand_total',
        ruleId: 'grand_total_calc',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Grand total (${actual.toDisplayString()}) does not match '
            'subtotal − discounts + VAT + fees = ${expected.toDisplayString()}',
        messageAr:
            'الإجمالي الكلي (${actual.toDisplayString()}) لا يتطابق مع '
            'الإجمالي الفرعي − الخصومات + ضريبة القيمة المضافة + الرسوم = ${expected.toDisplayString()}',
      ),
    ]);
  }

  /// Validates that sourceAmount − fee − commission ≈ [providedNetAmount].
  GeniusFinancialValidationResult validateTransferNet({
    required double sourceAmount,
    required double fee,
    required double commission,
    required double providedNetAmount,
  }) {
    final expected = _m(sourceAmount) - _m(fee) - _m(commission);
    final actual = _m(providedNetAmount);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'net_amount',
        ruleId: 'transfer_net',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Net amount (${actual.toDisplayString()}) does not match '
            'source − fee − commission = ${expected.toDisplayString()}',
        messageAr:
            'صافي المبلغ (${actual.toDisplayString()}) لا يتطابق مع '
            'المصدر − الرسوم − العمولة = ${expected.toDisplayString()}',
      ),
    ]);
  }

  /// Two-stage validation: rounds [sourceAmount] with [sourceCurrencyPolicy]
  /// (or [policy] if null), then validates the conversion using [policy].
  GeniusFinancialValidationResult validateCurrencyConversion({
    required double sourceAmount,
    required double exchangeRate,
    required double providedTargetAmount,
    GeniusRoundingPolicy? sourceCurrencyPolicy,
  }) {
    final srcPolicy = sourceCurrencyPolicy ?? policy;
    final sourceM = GeniusMoney.fromDouble(sourceAmount, policy: srcPolicy);
    final expected = sourceM.multiplyByRate(exchangeRate, policy: policy);
    final actual = _m(providedTargetAmount);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'target_amount',
        ruleId: 'currency_conversion',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Converted amount (${actual.toDisplayString()}) does not match '
            '${sourceM.toDisplayString()} × $exchangeRate = ${expected.toDisplayString()}',
        messageAr:
            'المبلغ المحوَّل (${actual.toDisplayString()}) لا يتطابق مع '
            '${sourceM.toDisplayString()} × $exchangeRate = ${expected.toDisplayString()}',
      ),
    ]);
  }

  /// Validates that sum(debits) == sum(credits) exactly (no tolerance).
  GeniusFinancialValidationResult validateAccountingEntries({
    required List<double> debits,
    required List<double> credits,
  }) {
    final debitSum = debits.fold(0.0, (s, v) => s + v);
    final creditSum = credits.fold(0.0, (s, v) => s + v);
    final debitM = _m(debitSum);
    final creditM = _m(creditSum);
    if (debitM.minorUnits == creditM.minorUnits) {
      return GeniusFinancialValidationResult.valid();
    }
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: 'debit_credit_balance',
        ruleId: 'accounting_balance',
        expectedValue: debitM,
        actualValue: creditM,
        message:
            'Accounting entries are not balanced: '
            'debits ${debitM.toDisplayString()} ≠ credits ${creditM.toDisplayString()}',
        messageAr:
            'القيود المحاسبية غير متوازنة: '
            'المدين ${debitM.toDisplayString()} ≠ الدائن ${creditM.toDisplayString()}',
      ),
    ]);
  }

  /// Validates that sum([rowValues]) ≈ [providedTotal] for a grid column.
  GeniusFinancialValidationResult validateGridColumn({
    required List<double> rowValues,
    required double providedTotal,
    required String columnId,
  }) {
    final sum = rowValues.fold(0.0, (s, v) => s + v);
    final expected = _m(sum);
    final actual = _m(providedTotal);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: columnId,
        ruleId: 'grid_column_sum',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Column "$columnId" total (${actual.toDisplayString()}) does not match '
            'sum of rows (${expected.toDisplayString()})',
        messageAr:
            'إجمالي العمود "$columnId" (${actual.toDisplayString()}) لا يتطابق مع '
            'مجموع الصفوف (${expected.toDisplayString()})',
      ),
    ]);
  }

  /// Validates that sum([values]) / count ≈ [providedAverage].
  GeniusFinancialValidationResult validateAverage({
    required List<double> values,
    required double providedAverage,
    required String columnId,
  }) {
    if (values.isEmpty) return GeniusFinancialValidationResult.valid();
    final avg = values.fold(0.0, (s, v) => s + v) / values.length;
    final expected = _m(avg);
    final actual = _m(providedAverage);
    if (_ok(expected, actual)) return GeniusFinancialValidationResult.valid();
    return GeniusFinancialValidationResult.invalid([
      GeniusFinancialValidationError(
        fieldId: columnId,
        ruleId: 'grid_column_average',
        expectedValue: expected,
        actualValue: actual,
        message:
            'Average for "$columnId" (${actual.toDisplayString()}) does not match '
            'computed average (${expected.toDisplayString()})',
        messageAr:
            'متوسط "$columnId" (${actual.toDisplayString()}) لا يتطابق مع '
            'المتوسط المحسوب (${expected.toDisplayString()})',
      ),
    ]);
  }

  /// Validates budget variance (actual − budget) and optional variance%.
  GeniusFinancialValidationResult validateBudgetVariance({
    required double actual,
    required double budget,
    required double providedVariance,
    double? providedVariancePct,
  }) {
    final errors = <GeniusFinancialValidationError>[];

    final expectedVariance = _m(actual) - _m(budget);
    final actualVariance = _m(providedVariance);
    if (!_ok(expectedVariance, actualVariance)) {
      errors.add(GeniusFinancialValidationError(
        fieldId: 'variance',
        ruleId: 'budget_variance',
        expectedValue: expectedVariance,
        actualValue: actualVariance,
        message:
            'Budget variance (${actualVariance.toDisplayString()}) does not match '
            'actual − budget = ${expectedVariance.toDisplayString()}',
        messageAr:
            'انحراف الميزانية (${actualVariance.toDisplayString()}) لا يتطابق مع '
            'الفعلي − الميزانية = ${expectedVariance.toDisplayString()}',
      ));
    }

    if (providedVariancePct != null && budget.abs() > 0) {
      final pct = (actual - budget) / budget.abs() * 100;
      final expectedPct = _m(pct);
      final actualPct = _m(providedVariancePct);
      if (!_ok(expectedPct, actualPct)) {
        errors.add(GeniusFinancialValidationError(
          fieldId: 'variance_pct',
          ruleId: 'budget_variance_pct',
          expectedValue: expectedPct,
          actualValue: actualPct,
          message:
              'Variance % (${actualPct.toDisplayString()}) does not match '
              'computed ${expectedPct.toDisplayString()}%',
          messageAr:
              'نسبة الانحراف (${actualPct.toDisplayString()}) لا تتطابق مع '
              'المحسوبة ${expectedPct.toDisplayString()}%',
        ));
      }
    }

    return errors.isEmpty
        ? GeniusFinancialValidationResult.valid()
        : GeniusFinancialValidationResult.invalid(errors);
  }

  /// Pre-rounds [rawAmount] to the safe value to pass to amount-to-words.
  double roundForWords(double rawAmount) => policy.round(rawAmount);

  /// Merges a list of results into one combined result.
  GeniusFinancialValidationResult combineResults(
    List<GeniusFinancialValidationResult> results,
  ) =>
      GeniusFinancialValidationResult.combine(results);
}
