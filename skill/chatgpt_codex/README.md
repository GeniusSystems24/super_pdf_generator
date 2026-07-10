# Skill: `super_pdf_generator` for ChatGPT Codex

**Agent focus:** modular implementation · strong API understanding · incremental
development · test-driven workflows · code-generation consistency.

## What this package is

`super_pdf_generator` (product identity **Folio — PDF Document SDK**) is a typed,
framework-independent Flutter PDF SDK. A document is immutable data built with a
fluent builder (`pdfDocument()` + `pdf.*`), rendered behind a `PdfRenderer` port,
and delivered/processed through platform gateways. `PdfClient` is the single
facade. Clean Architecture with an *executable* boundary test.

## Read these first (in order)

1. `architecture.md` — layers, rendering pipeline, dependency rules, folder map.
2. `coding_standards.md` — naming, docs, error handling, null safety, lint gate.
3. `examples.md` — reusable recipes (templates, components, renderers, fonts,
   themes, RTL/Arabic, tables, printing, preview, saving, exporting).
4. `migration_notes.md` — source→target mapping and deferred parity.
5. `workflow.md` — the incremental, test-driven loop tuned for Codex.
6. `best_practices.md` — codegen-consistency rules and common mistakes.

## Folder map (where things go)

- Pure data & rules → `lib/src/domain/**`
- Ports, builder, templates, jobs, facade → `lib/src/application/**`
- Engines & platform → `lib/src/infrastructure/**` (only layer importing `pdf`/`printing`)
- Presentation models → `lib/src/presentation/**`
- Wiring → `lib/src/composition/**`
- Tests → `test/{domain,application,architecture,public_api,financial}/**`

## Codex operating contract

- Generate **one cohesive unit at a time** (a file or a tight cluster), each with
  its test, then run the gate. Do not emit multi-file rewrites in a single step.
- Treat the public barrel as the API contract. If you touch it, update
  `test/public_api/api_compat_test.dart` in the same change.
- Never import `pdf`/`printing` outside `infrastructure/`.
