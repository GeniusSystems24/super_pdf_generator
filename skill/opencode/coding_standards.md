<!-- Skill pack: OpenCode — shared project reference (identical across agents by design). -->

# Coding Standards — `super_pdf_generator`

> Shared across all skill packs. These are the rules every contribution (human or
> agent) must satisfy before merge.

## 1. Naming conventions

| Element | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `pdf_client.dart`, `tax_invoice_template.dart` |
| Types | `PascalCase` | `PdfClient`, `GeniusMoney`, `PdfFailure` |
| Members / locals | `camelCase` | `currentY`, `buildChecked()` |
| Constants | `camelCase` (`lowerCamel`) | `defaultMargin`, `a4PortraitMargins` |
| Ports (interfaces) | noun of the capability | `PdfRenderer`, `PrintGateway` |
| Use cases | verb-noun | `GenerateDocument`, `InspectDocument` |

## 2. Documentation standards

- Every **public** type, constructor, and method carries a `///` doc comment: a
  one-line summary, then detail, then a fenced `dart` example for non-trivial
  APIs. Parameters are described when their meaning is not obvious.
- The first sentence is a noun/verb phrase, not "This class…".
- Keep examples runnable and minimal.

## 3. Error handling — typed, never thrown for expected conditions

```dart
sealed class PdfFailure {
  const PdfFailure({required this.code, required this.message, this.messageAr, this.retryable = false});
  final String code;
  final String message;
  final String? messageAr;
  final bool retryable;
}

sealed class Result<T> {
  const Result();
  R fold<R>(R Function(T ok) onOk, R Function(PdfFailure err) onErr);
}
class Ok<T> extends Result<T> { const Ok(this.value); final T value; }
class Err<T> extends Result<T> { const Err(this.failure); final PdfFailure failure; }
```

- Public methods return `Result<T>` / `Future<Result<T>>`. Exceptions are reserved
  for programmer errors (contract violations), not expected runtime conditions.
- Every failure is bilingual: `message` (EN) + `messageAr` (AR) and states
  `retryable`.

## 4. Null safety

- Sound null safety throughout; no `late` unless a field is provably assigned
  before first read. Prefer `final` fields and `const` constructors.
- Fall back with `??` at the edge (e.g. `this.props.x ?? default`), not deep in
  the call graph.

## 5. Immutability & value semantics

- Domain models are immutable: `final` fields, `const` constructors where
  possible, `copyWith`, value `==`/`hashCode` (or an equality mixin).
- The document tree must survive `toJson()`/`fromJson()` losslessly — this is
  what lets generation cross the isolate boundary.

## 6. Bilingual & RTL rules

- Every user-facing string has an English form and an Arabic form
  (`title`/`titleAr`, `label`/`labelAr`, `message`/`messageAr`).
- RTL is a layout mode, not a text trick: mirror alignment, table column order,
  and header blocks. Western digits are kept in both languages
  (`$5,240.00`, `JV-2024-0042`).
- Amount-in-words is available in EN and AR.

## 7. Factory constructors for common presets

Follow the source's adopted style — expose named factories for frequent configs:

```dart
factory PrintSettings.draft() => ...;
factory PrintSettings.highQuality() => ...;
factory GeniusRoundingPolicy.forCurrency(String code) => ...;
```

## 8. Performance recommendations

- Do heavy generation off the main isolate (`IsolateRenderRunner`); keep the
  document serializable so it can transfer.
- Prefer lossless Syncfusion processing over rasterize-and-recompose.
- Batch work through the job queue with a concurrency limit; report progress via
  streams rather than polling.
- Register fonts once (`FontRegistry`) and reuse the bytes; do not re-decode per
  document.

## 9. Analyzer / lint gate

`analysis_options.yaml` builds on `flutter_lints` and additionally enforces:
`prefer_single_quotes`, `sort_constructors_first`, `prefer_final_fields`,
`prefer_final_locals`, `avoid_print`, `prefer_const_constructors`,
`prefer_const_declarations`. `unused_element` is an **error-level warning**.

**Gate:** `dart format --set-exit-if-changed .` and `flutter analyze` must be
clean; there are zero analyzer infos/warnings on a mergeable branch.

## 10. Tests are part of the definition of done

- New domain logic → a `test/domain` case.
- New port/use case → an application test with fakes.
- New public symbol → covered by `test/public_api/api_compat_test.dart`.
- No new cross-layer import may pass `test/architecture/boundary_test.dart`.
