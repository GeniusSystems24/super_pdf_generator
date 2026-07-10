# Workflow — ChatGPT Codex

Optimized for **incremental, test-driven** development with consistent codegen.

## The loop (repeat per unit of work)

1. **Locate** the seam. Identify the single file or tight cluster to change and
   the layer it belongs to (domain / application / infrastructure / presentation).
2. **Write the test first.** Add or extend a case under the matching `test/`
   folder. For a new public symbol, extend `api_compat_test.dart`.
3. **Implement the minimum** to satisfy the test, matching existing file style
   (factory constructors, `Result<T>`, bilingual fields, immutable data).
4. **Run the gate:**
   ```bash
   dart format --set-exit-if-changed .
   flutter analyze
   flutter test
   ```
5. **Stop at green.** Commit the unit. Move to the next.

## Feature implementation process

1. Add the immutable domain node / value object first (pure, `toJson`-able).
2. Expose it through the application layer (builder factory, port method, or use
   case).
3. Map it in infrastructure (`pw_mapper`) with a raster fallback if needed.
4. Wire any new adapter in the composition root.
5. Add the example destination in `example/` and a public-API test.

## Bug-fixing process

1. Reproduce with a failing test at the correct layer.
2. Fix in the layer that owns the defect (not at the call site).
3. Keep the fix behavior-preserving elsewhere; re-run the full gate.
4. Add a regression test named after the symptom.

## Testing workflow

- `test/domain` — money/rounding/validation, JSON round-trip, failure taxonomy.
- `test/application/job_queue_test.dart` — run/retry-with-backoff/cancel/priority.
- `test/architecture/boundary_test.dart` — illegal imports fail the build.
- `test/public_api/api_compat_test.dart` — the whole public surface compiles.
- `test/financial` — audit-grade financial rules.

## Documentation update process

On any public change: update the `///` docs, the README usage snippet, and the
relevant `skill/*` file if a pattern changed. Docs and code ship together.
