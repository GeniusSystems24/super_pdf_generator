# Skill: `super_pdf_generator` for OpenCode

**Agent focus:** fast repository navigation · workspace-aware editing · efficient
incremental changes · high-performance development · minimal-context code
modifications.

## What this package is

`super_pdf_generator` (**Folio — PDF Document SDK**) — a typed, framework-free
Flutter PDF SDK. Immutable document data (`pdfDocument()` + `pdf.*`) rendered
behind ports; one `PdfClient` facade; Clean Architecture guarded by a boundary
test.

## Fast orientation (minimal context)

- **Contract:** `lib/super_pdf_generator.dart` (the public barrel — read this to
  know the surface without reading `src/`).
- **Where code lives:**
  - rules/data → `lib/src/domain/**`
  - ports/builder/templates/jobs/facade → `lib/src/application/**`
  - engines/platform → `lib/src/infrastructure/**` (only place `pdf`/`printing`
    are imported)
  - wiring → `lib/src/composition/composition_root.dart`
- **Tests:** `test/{domain,application,architecture,public_api,financial}`.

## Jump table (grep targets)

| Need | Search |
|---|---|
| Public API | open `lib/super_pdf_generator.dart` |
| A component factory | `pdf.` in `application/builder.dart` |
| A port | `abstract class .*Gateway|Renderer|Inspector` in `application/contracts.dart` |
| Rendering | `infrastructure/rendering/pw_mapper.dart` |
| A template | `application/templates/business/` |
| Wiring | `createPdfClient|createStudioClient` |

## Read next

`architecture.md` (rules), `coding_standards.md` (invariants), `examples.md`
(recipes), `workflow.md` (surgical edit loop), `best_practices.md`,
`migration_notes.md`.
