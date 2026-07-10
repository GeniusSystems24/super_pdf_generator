# Best Practices — ChatGPT Codex

Focus: **code-generation consistency** and **strong API understanding**.

## Consistency rules (make generated code look hand-written)

- Match the surrounding file's shape: `sort_constructors_first`,
  `prefer_single_quotes`, `const` constructors, `final` fields.
- Reuse existing value objects and ports — do not invent a parallel type when
  `PdfPageSize`, `PdfMargins`, `Result<T>`, or a gateway already exists.
- Name factories after intent (`.draft()`, `.highQuality()`, `.forCurrency()`),
  mirroring the established pattern.
- Every public symbol: doc comment + minimal `dart` example.

## API-first discipline

- Before generating, state the smallest public delta (new type, new method,
  changed signature). If the delta touches the barrel, plan the
  `api_compat_test.dart` change in the same unit.
- Prefer additive changes. A breaking change requires a major-version note and a
  migration entry.

## Incremental generation

- One unit per step, each independently compilable and tested. Avoid sprawling
  multi-file generations that can't be verified in isolation.
- Keep diffs surgical — don't reformat untouched regions.

## Guardrails

- Never import `pdf` / `printing` / `syncfusion_flutter_pdf` outside
  `infrastructure/`.
- Never throw for an expected condition — return `Err(PdfFailure(...))`.
- Never add a non-serializable document node.
- Keep Arabic/RTL parity: new user-facing strings need `...Ar` counterparts.

## Common mistakes to avoid

- Emitting a whole file when a three-line edit suffices.
- Forgetting the test, then discovering a boundary violation late.
- Hand-summing totals instead of using `GeniusFinancialValidator`.
- Constructing an adapter inside a controller instead of injecting it.
