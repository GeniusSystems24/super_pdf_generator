# Workflow — OpenCode

Optimized for **fast navigation** and **minimal-context, surgical edits**.

## The surgical loop

1. **Find the seam by name.** Use the jump table in `README.md`; grep for the
   symbol, don't read whole layers.
2. **Confirm the layer.** The file's path tells you the rules (domain = pure;
   only infrastructure imports `pdf`/`printing`).
3. **Edit in place.** Change the smallest span. Keep the diff tight; don't
   reformat untouched code.
4. **Gate fast:**
   ```bash
   dart format --set-exit-if-changed .
   flutter analyze
   flutter test test/<the-relevant-suite>   # then the full suite before commit
   ```

## Efficient incremental changes

- Prefer editing an existing file over adding a new one; reuse existing value
  objects and ports.
- Batch related one-liners into a single pass; run the analyzer once at the end.
- For a new public symbol, update `test/public_api/api_compat_test.dart` in the
  same edit so the contract stays covered.

## Feature / bug / docs (fast paths)

- **Feature (small):** domain node → `pdf.*` factory → `pw_mapper` case → one
  test. Skip ceremony; keep it vertical and minimal.
- **Bug:** add the smallest failing test at the owning layer, fix, re-run that
  suite, then the full gate.
- **Docs:** update the `///` and the one README snippet touched. Don't rewrite
  unrelated docs.

## Performance mindset

- Off-main-isolate generation and lossless processing are already wired — reuse
  them; don't add rasterization paths.
- Register fonts once; reuse bytes. Don't re-decode per document.

## Guardrails (non-negotiable, even for tiny edits)

- No `pdf`/`printing` import outside `infrastructure/`.
- No thrown control flow — return `Err(PdfFailure(...))`.
- No non-serializable document node.
- Keep `...Ar` bilingual counterparts for new user-facing strings.
