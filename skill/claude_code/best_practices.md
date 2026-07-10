# Best Practices — Claude Code

Focus: **architectural reasoning** and **large-scale refactoring** that preserves
behavior.

## Reason from the boundary inward

- State the layer rule before you edit: domain is pure; application is
  Flutter-free; only infrastructure touches `pdf`/`printing`. If a change would
  break that, the design is wrong — move the code, don't relax the rule.
- Keep the document model **data**. Anything that can't `toJson()` doesn't belong
  in the tree; push behavior to the application/infrastructure layers.

## Preserve behavior across big changes

- Treat `api_compat_test.dart` and `boundary_test.dart` as the contract. Green
  before, green after.
- When re-expressing a source mechanism (e.g. imperative builder → fluent data),
  map every source capability to a target home first (see `migration_notes.md`),
  then implement. No capability silently disappears.
- Prefer decomposition (collaborators, ports) over adding flags to a growing
  class.

## Progress tracking is a first-class deliverable

- Keep `development_plan_v1.0.0.md` §4 truthful: ✅ / 🟨 / ⬜ with rationale.
- Every deferral is a tracked promise with a re-entry version, not an omission.

## Multi-phase hygiene

- Land vertical slices, not horizontal layers half-done across the repo.
- Don't start Phase N+1 while Phase N's acceptance criteria are unmet unless the
  slice genuinely spans both — and then update both checklist rows.

## Common mistakes to avoid

- Refactoring the domain to satisfy an infrastructure convenience.
- Letting a Syncfusion/`pdf` type surface in the public barrel.
- Rasterizing to process when the lossless processor exists.
- Dropping Arabic/RTL parity during a rename.
- Marking a phase done without running the example's analyze/test.
