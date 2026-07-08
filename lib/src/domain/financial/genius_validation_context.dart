// DOMAIN · financial · validation context. Pure Dart.

import 'genius_rounding_policy.dart';

/// Carries rounding configuration into a template's generate/validate call.
///
/// If not supplied, defaults to [GeniusRoundingPolicy.defaults()].
class GeniusFinancialValidationContext {
  GeniusFinancialValidationContext({
    GeniusRoundingPolicy? roundingPolicy,
    this.sourceCurrencyPolicy,
    this.documentCurrency = 'SAR',
  }) : roundingPolicy = roundingPolicy ?? GeniusRoundingPolicy.defaults();

  /// Document-currency rounding policy (primary).
  final GeniusRoundingPolicy roundingPolicy;

  /// Source-currency policy for multi-currency documents.
  final GeniusRoundingPolicy? sourceCurrencyPolicy;

  /// ISO 4217 document currency code.
  final String documentCurrency;
}
