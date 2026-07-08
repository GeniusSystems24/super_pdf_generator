// DOMAIN · financial · validation result. Pure Dart.

import 'genius_money.dart';

/// A single rule violation found during financial validation.
class GeniusFinancialValidationError {
  const GeniusFinancialValidationError({
    required this.fieldId,
    required this.ruleId,
    required this.expectedValue,
    required this.actualValue,
    required this.message,
    required this.messageAr,
  });

  /// Machine-readable field identifier (e.g. 'subtotal', 'vat_amount').
  final String fieldId;

  /// Rule that failed (e.g. 'subtotal_sum', 'vat_calc').
  final String ruleId;

  final GeniusMoney expectedValue;
  final GeniusMoney actualValue;

  /// English error message.
  final String message;

  /// Arabic error message.
  final String messageAr;
}

/// The aggregate outcome of validating a document.
class GeniusFinancialValidationResult {
  const GeniusFinancialValidationResult._({
    required this.isValid,
    required this.errors,
  });

  factory GeniusFinancialValidationResult.valid() =>
      const GeniusFinancialValidationResult._(
        isValid: true,
        errors: <GeniusFinancialValidationError>[],
      );

  factory GeniusFinancialValidationResult.invalid(
    List<GeniusFinancialValidationError> errors,
  ) {
    assert(errors.isNotEmpty, 'An invalid result must have at least one error');
    return GeniusFinancialValidationResult._(isValid: false, errors: errors);
  }

  /// Merges a list of results into one. Valid if all are valid.
  static GeniusFinancialValidationResult combine(
    List<GeniusFinancialValidationResult> results,
  ) {
    final allErrors = results.expand((r) => r.errors).toList();
    return allErrors.isEmpty
        ? GeniusFinancialValidationResult.valid()
        : GeniusFinancialValidationResult.invalid(allErrors);
  }

  final bool isValid;
  final List<GeniusFinancialValidationError> errors;
}
