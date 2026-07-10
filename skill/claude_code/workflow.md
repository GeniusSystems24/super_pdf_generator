# Workflow — Claude Code

Optimized for **long-running, multi-phase** migration with **progress tracking**.

## Run the migration as tracked phases

Maintain a live todo mirroring `development_plan_v1.0.0.md` §3/§4. Each phase has
acceptance criteria; a phase is done only when its criteria are objectively met
and the gate is green.

```
Phase 1 Core & domain        Phase 4 Rendering & processing   Phase 7 Platform/printing
Phase 2 Public API           Phase 5 Jobs & batch             Phase 8 Example (Studio)
Phase 3 Document & builder   Phase 6 Templates                Phase 9 Tests/docs/skills
```

## The disciplined loop

1. **Understand before editing.** Read the target files in the layer you'll
   touch and the boundary test's rules. Restate the invariant you must preserve.
2. **Plan the slice.** Pick the smallest vertical slice that advances a checklist
   item end-to-end (domain node → application exposure → infra mapping → test →
   example).
3. **Implement inward-out.** Domain first (pure, serializable), then application,
   then infrastructure, then composition wiring.
4. **Prove it.** `dart format --set-exit-if-changed . && flutter analyze &&
   flutter test`, plus the example's analyze/test.
5. **Record progress.** Tick the checklist item; note any newly-discovered
   deferrals in §5 with rationale.

## Large-scale refactoring

- Refactor behind the public barrel; keep `api_compat_test.dart` green so the
  contract never silently shifts.
- Move engine code *into* `infrastructure/` if you find it leaking; the boundary
  test is your safety net.
- Decompose god-classes into collaborators (as the job queue was) rather than
  adding parameters.

## Feature / bug / docs processes

- **Feature:** advance a checklist item as a full vertical slice; update plan +
  docs + example + tests together.
- **Bug:** reproduce with a layer-correct failing test; fix in the owning layer;
  add a regression test; re-run the whole gate.
- **Docs:** every public change updates `///` docs, README, and the affected
  `skill/*` and `migration/` artifacts in the same change.

## Testing workflow

Run the full suite (domain, application/job_queue, architecture/boundary,
public_api/api_compat, financial) and the example. Never merge with a red gate or
an unexplained deferral.
