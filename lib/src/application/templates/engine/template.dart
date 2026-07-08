// APPLICATION · templates · engine. Pure Dart.
//
// A declarative template turns a typed data model into an immutable
// [PdfDocumentDefinition], and can validate that data (financially and
// structurally) before rendering. Adopted from the GeniusLink PDF reference's
// template engine and re-expressed against Folio's domain.

import '../../../domain/document.dart';
import '../../../domain/financial/genius_rounding_policy.dart';
import '../../../domain/financial/genius_validation_result.dart';
import '../../../domain/theme.dart';
import '../../../domain/value_objects.dart';

/// Spelling/label language for template output.
enum PdfTemplateLanguage { english, arabic }

/// Rendering context threaded into a template's build/validate call.
class PdfTemplateContext {
  PdfTemplateContext({
    GeniusRoundingPolicy? roundingPolicy,
    this.language = PdfTemplateLanguage.english,
    PdfDirection? direction,
    this.theme,
    this.locale,
  })  : roundingPolicy = roundingPolicy ?? GeniusRoundingPolicy.defaults(),
        direction = direction ??
            (language == PdfTemplateLanguage.arabic
                ? PdfDirection.rtl
                : PdfDirection.ltr);

  /// How monetary values are rounded and validated.
  final GeniusRoundingPolicy roundingPolicy;

  /// Output language for built-in labels and amount-in-words.
  final PdfTemplateLanguage language;

  /// Text direction (defaults from [language]).
  final PdfDirection direction;

  /// Optional theme override; templates fall back to their own default.
  final PdfTheme? theme;

  /// BCP-47 locale hint (e.g. 'ar-SA', 'en-US').
  final String? locale;

  bool get isArabic => language == PdfTemplateLanguage.arabic;

  factory PdfTemplateContext.arabic({GeniusRoundingPolicy? roundingPolicy, PdfTheme? theme}) =>
      PdfTemplateContext(
        roundingPolicy: roundingPolicy,
        language: PdfTemplateLanguage.arabic,
        theme: theme,
        locale: 'ar-SA',
      );
}

/// A declarative document template over a typed data model [TData].
abstract class PdfTemplate<TData> {
  const PdfTemplate();

  /// Stable machine identifier, e.g. 'tax_invoice'.
  String get id;

  /// Human-readable English name.
  String get name;

  /// Human-readable Arabic name.
  String get nameAr;

  /// Short description of what the template produces.
  String get description => '';

  /// Validate [data] before building (financial + structural). Override to
  /// enforce that provided totals match recomputed ones.
  GeniusFinancialValidationResult validate(
    TData data, {
    PdfTemplateContext? context,
  }) =>
      GeniusFinancialValidationResult.valid();

  /// Build the immutable document from [data].
  PdfDocumentDefinition build(TData data, {PdfTemplateContext? context});

  /// Convenience: validate then build. Returns a [PdfTemplateResult] carrying
  /// both the (optional) document and any validation errors.
  PdfTemplateResult buildChecked(TData data, {PdfTemplateContext? context}) {
    final ctx = context ?? PdfTemplateContext();
    final validation = validate(data, context: ctx);
    if (!validation.isValid) {
      return PdfTemplateResult(document: null, validation: validation);
    }
    return PdfTemplateResult(
      document: build(data, context: ctx),
      validation: validation,
    );
  }
}

/// The outcome of [PdfTemplate.buildChecked].
class PdfTemplateResult {
  const PdfTemplateResult({required this.document, required this.validation});

  /// Null when [validation] failed.
  final PdfDocumentDefinition? document;
  final GeniusFinancialValidationResult validation;

  bool get isValid => validation.isValid && document != null;
}
