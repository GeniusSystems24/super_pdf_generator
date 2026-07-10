# Skill: `super_pdf_generator` for Claude Code

**Agent focus:** deep repository understanding · long-running implementation
plans · multi-phase migrations · architectural reasoning · progress tracking ·
large-scale refactoring.

## What this package is

`super_pdf_generator` (**Folio — PDF Document SDK**) is a typed,
framework-independent Flutter PDF SDK. Documents are immutable data
(`pdfDocument()` + `pdf.*`), rendered behind ports, delivered/processed through
platform gateways, and driven by one `PdfClient` facade. Clean Architecture is
enforced by `test/architecture/boundary_test.dart`.

## Read these first

1. `architecture.md` — the system model, layers, rendering pipeline, rules.
2. `migration_notes.md` — the source→target mapping and what was intentionally
   replaced or deferred (essential for reasoning about parity).
3. `coding_standards.md` — the invariants every change preserves.
4. `examples.md` — the reusable patterns.
5. `workflow.md` — how to run a multi-phase migration with progress tracking.
6. `best_practices.md` — architectural-reasoning and refactoring guidance.

Also load `../../development_plan_v1.0.0.md` — it holds the phase plan, the
source→target checklist, and the deferred-items ledger. Treat it as the backlog.

## Why Claude Code fits this repo

The migration is inherently multi-phase (core → API → model → rendering → jobs →
templates → platform → example → docs) with a boundary contract that must hold
at every step. That rewards a long-running plan, explicit progress tracking, and
architectural reasoning over local edits.

## Orientation checklist (do once per session)

- Skim the public barrel `lib/super_pdf_generator.dart` to see the contract.
- Skim `development_plan_v1.0.0.md` §4 (checklist) for current state.
- Confirm the boundary test still passes before and after your change.
