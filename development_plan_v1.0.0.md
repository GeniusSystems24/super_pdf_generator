# Development & Migration Plan — `super_pdf_generator` v1.0.0

> **Source of truth:** `GeniusSystems24/genius_link_pdf_generator` @ `main` (v3.7.0)
> **Target package:** `flutter/super_pdf_generator` (product identity: **Folio — PDF Document SDK**)
> **Document status:** Living plan. Update the checklist and acceptance columns on every change.
> **Last updated:** 2026-07-10 — v1.0.0 feature work delivered (security, export, offline intelligence, voucher family, share targets); dependencies bumped. See `CHANGELOG.md`.

---

## 0. Purpose

This plan governs the complete migration of every functional component of the
source package into `super_pdf_generator`. The target is a **behavior-preserving,
architecture-improving** re-expression of the source: the same capabilities, a
cleaner public surface, strict layer boundaries, and comprehensive docs.

The plan is organized as nine phases (analysis → validation → documentation →
AI skills → final report). Each phase carries **measurable acceptance criteria**
and a **checklist** that must reach 100% before the migration is declared
complete.

### Non-negotiable principles

1. **Behavior parity first.** No feature is dropped because it appears unused.
   Every capability the source ships must have a home (migrated, superseded, or
   explicitly deferred with rationale).
2. **Clean Architecture, enforced.** Domain and Application layers are pure Dart
   (no Flutter, `dart:ui`, `dart:io`, `pdf`, or `printing`). Infrastructure is
   the only layer that touches the PDF engine. Boundaries are guarded by an
   executable test (`test/architecture/boundary_test.dart`).
3. **Typed outcomes, never thrown control flow.** Expected failures flow through
   `Result<T>` (`Ok`/`Err`) and a `sealed PdfFailure` taxonomy.
4. **Isolate-serializable document model.** The document is *data*
   (`toJson()`/`fromJson()`), so generation can move off the main isolate.
5. **Bilingual by construction.** Every user-facing string has an English and an
   Arabic form; RTL is a first-class layout mode, not an afterthought.

---

## 1. Source inventory (what we are migrating)

Counts are exact file counts from the source tree at the pinned ref.

| Area | Path | Files | Notes |
|---|---|---:|---|
| Public barrels | `lib/*.dart` | 3 | `genius_link_pdf_generator.dart` (full), `_api.dart` (focused), `libraries.dart` |
| Core | `lib/src/core/**` | 27 | config, assets, logger (5), print theme (10), **v2** (7: cache, DI, events, fluent, platform, plugin) |
| Domain | `lib/src/domain/**` | 10 | financial (6), models (delivery/operations/result) |
| Application | `lib/src/application/**` | 5 | contracts (2), services (2) |
| Builders | `lib/src/builders/**` | 3 | `document_builder.dart` (54 KB), `report_composer.dart` |
| Components | `lib/src/components/**` | 43 | grid, rich text, info box, report header, summary, barcode, watermark, digital signature |
| Composition | `lib/src/composition/**` | 1 | composition root |
| Extensions | `lib/src/extensions/**` | 2 | color, datetime |
| Infrastructure | `lib/src/infrastructure/**` | 5 | generation, logging, platform (2), Syncfusion processing |
| Models | `lib/src/models/**` | 2 | image, result alias |
| Presentation | `lib/src/presentation/**` | 5 | controllers (3), preview view |
| Printing | `lib/src/printing/**` | 21 | discovery, settings, preview (4), printer service (3) |
| Public facade | `lib/src/public/**` | 2 | `GeniusPdfClient`, preview controller |
| Services | `lib/src/services/**` | 18 | pdf service, security, generation manager, export (7), job management (8) |
| Sharing | `lib/src/sharing/**` | 6 | app, bluetooth, email, share service, models |
| AI | `lib/src/ai/**` | 5 | content analyzer, image optimizer, layout engine, text services |
| Templates | `lib/templates/**` | 49 | 16 business + engine (6) + vouchers (models 4 + 19 templates) |
| Example app | `example/lib/**` | 94 | feature-first, MVC; 16 feature areas |
| **Total (lib+example)** | | **~305** | plus tests, specs, docs, workflows |

### Dependency review

| Package | Source use | Decision in target |
|---|---|---|
| `pdf` | primary generation engine | **Keep** — behind `PdfRenderer` port (infrastructure only) |
| `syncfusion_flutter_pdf` | lossless merge/split/rotate/watermark + inspect | **Keep** — behind `PdfInspector`/processor port; studio client only |
| `printing` | print / share / raster fallback | **Keep** — platform gateway |
| `path_provider`, `open_file`, `cross_file` | file save/open | **Keep** — file gateway |
| `share_plus`, `url_launcher` | share sheet, email compose | **Keep** — share/email gateways |
| `shared_preferences` | print-settings persistence | **Keep** — settings gateway (optional) |
| `intl` | number/date formatting | **Keep** — used by financial + templates |
| `image` | raster helpers | **Keep** — raster fallback only |
| `barcode` | QR/barcode glyphs | **Keep** — barcode/QR components |

No dependency is removed. All are pushed to the **infrastructure** boundary so
the domain/application layers stay pure and unit-testable without plugins.

---

## 2. Target architecture (where it lands)

```
lib/
├── super_pdf_generator.dart        # single canonical public barrel
├── pdf_generator.dart              # convenience alias (re-exports the barrel)
└── src/
    ├── domain/          # pure Dart: value objects, theme, components, document,
    │   └── financial/   #   document_info, generation, processing, printing, jobs,
    │                    #   failures (Result + sealed PdfFailure); financial money/rounding/validator
    ├── application/      # contracts (ports), fluent builder + pdf.* factory,
    │   ├── templates/    #   declarative business templates (engine + registry + business)
    │   ├── jobs/         #   queue collaborators (policy, repo, retry, scheduler, progress, stats, queue)
    │   └── ...           #   usecases, pdf_client facade
    ├── infrastructure/   # ONLY layer importing pdf/printing/syncfusion
    │   ├── rendering/    #   pw_mapper, widget renderer, syncfusion processor, processing decorator, isolate runner
    │   └── platform/     #   print/share/email/file gateways
    ├── presentation/     # builder_controller (ChangeNotifier presentation model)
    └── composition/      # composition_root: createPdfClient / createStudioClient
```

**Layer rule (enforced):** `Presentation → Application → Domain`;
`Infrastructure → Application contracts`; composition root wires concretes.

---

## 3. Phase plan & acceptance criteria

Each phase is **DONE** only when every acceptance criterion is objectively met.

### Phase 1 — Core & domain
- [x] Value objects (page size, orientation, margins, colors, alignment) as immutable types.
- [x] `PdfTheme`/`PdfPalette` document-theme tokens (RTL, branded, light).
- [x] Financial domain: `GeniusMoney` (integer minor units), `GeniusRoundingPolicy`, `GeniusFinancialValidator`, validation context/result.
- [x] `Result<T>` + `sealed PdfFailure` taxonomy with `retryable`/`code`/`message`(+Ar).
- **Acceptance:** domain compiles with zero Flutter imports; `domain_test.dart` covers money arithmetic, rounding, validation, and failure taxonomy.

### Phase 2 — Public API surface
- [x] One barrel `super_pdf_generator.dart`; convenience alias `pdf_generator.dart`.
- [x] `PdfClient` facade (generate / process / inspect / print / share / email / jobs).
- [x] `pdfDocument()` fluent builder + `pdf.*` component factory.
- **Acceptance:** `api_compat_test.dart` compiles the whole public surface and exercises discriminated unions; no `src/` leakage of internal types.

### Phase 3 — Document model & builder
- [x] Immutable `PdfDocumentDefinition` with `toJson()`/`fromJson()` round-trip.
- [x] Components: heading, paragraph, table (zebra), status badge, spacer, divider, image, rich text, info box, report header, summary.
- [ ] **Gap:** barcode / QR component parity (source ships `pdf_barcode.dart`, `pdf_digital_signature.dart`). _Deferred — see §5._
- **Acceptance:** JSON round-trip is loss-free; builder output is deterministic; components render through the `pdf` mapper.

### Phase 4 — Rendering & processing infrastructure
- [x] `pw_mapper` (pure `pdf`-package mapper, isolate-safe).
- [x] `widget_pdf_renderer` (render + raster fallback).
- [x] `syncfusion_pdf_processor` (lossless merge/split/extract/rotate/watermark + inspect).
- [x] `processing_renderer` decorator; `isolate_render_runner` (off-main-isolate).
- **Acceptance:** merge/split/rotate/watermark keep text selectable; `inspect()` returns page count, metadata, per-page geometry without rendering.

### Phase 5 — Jobs & batch
- [x] Composed queue: `queue_policy`, `job_repository`, `retry_policy`, `scheduler`, `progress_reporter`, `queue_statistics`, `job_queue`.
- [x] Priority ordering, retry-with-backoff, cancel, live `watch()` stream, `stats()`.
- **Acceptance:** `job_queue_test.dart` proves run / retry-with-backoff / cancel / priority ordering and concurrency limits.

### Phase 6 — Templates
- [x] Template engine (`PdfTemplate` + `PdfTemplateContext`) and `defaultTemplateRegistry()`.
- [x] 18 business templates across Financial / Sales / HR / Vouchers, each language-aware with amount-in-words (EN/AR) and `buildChecked()` validation.
- [x] Voucher family expanded to 13 registered voucher types via a shared `VoucherTemplateBase` (payment/receipt, expense, petty cash, journal, contra, bank/cash payment & receipt, salary, advance, refund, deposit).
- **Acceptance:** every template recomputes and validates totals before build; Arabic output is RTL with Arabic labels.

### Phase 7 — Platform, printing & delivery
- [x] `PrintGateway.printDocument(PrintSettings?, PrinterDevice?)`, `listPrinters()` via `PrinterDiscovery`.
- [x] `ShareGateway`, `EmailGateway` (compose), `FileGateway`.
- **Acceptance:** print/share/email/save execute through injected gateways; unit tests use fakes (no plugin channels).

### Phase 8 — Example app (Folio Studio)
- [x] 14 destinations mirroring the approved Web IA (dashboard, builder, gallery, preview, printing, processing, batch, jobs, RTL, errors, performance, templates, API reference, settings).
- [ ] **Gap:** parity with the source example's 16 feature areas (AI features, barcode, security demos). _Deferred — see §5._
- **Acceptance:** every public API is exercised by at least one destination; demo compiles.

### Phase 9 — Testing, docs & AI skills
- [x] Test suites: domain, application/job queue, architecture boundary, public API compat, financial.
- [x] Docs: README, architecture, migration notes, api overview, examples.
- [x] AI skill packs: `skill/chatgpt_codex`, `skill/claude_code`, `skill/opencode`.
- **Acceptance:** `flutter analyze` and `dart format --set-exit-if-changed` are clean; docs cross-link; each skill pack has all seven required files.

---

## 4. Source → target migration checklist

Legend: ✅ migrated · 🟨 partial/superseded · ⬜ deferred (rationale in §5)

| # | Source module | Target home | State |
|---:|---|---|---|
| 1 | `core/pdf_config`, `pdf_assets` | `domain/value_objects`, `composition_root` (font registry) | ✅ |
| 2 | `core/pdf_logger/**` | `application/contracts` (logger port) + `infrastructure/support` | ✅ |
| 3 | `core/pdf_print_theme/**` | `domain/theme` (`PdfTheme`/`PdfPalette`) | ✅ |
| 4 | `core/v2/**` (cache, DI, events, fluent, plugin, platform) | Folded into clean layering + composition root | 🟨 superseded |
| 5 | `domain/financial/**` | `domain/financial/**` (1:1) | ✅ |
| 6 | `domain/models/**` (result, delivery, operations) | `domain/failures`, `domain/generation`, `domain/processing` | ✅ |
| 7 | `application/contracts/**` | `application/contracts.dart` (ports) | ✅ |
| 8 | `application/services/**` | `application/usecases.dart` | ✅ |
| 9 | `builders/document_builder` (imperative) | `application/builder` (immutable fluent `pdfDocument()`) | 🟨 re-expressed |
| 10 | `builders/report_composer` | `application/builder` fluent composition | ✅ |
| 11 | `components/widgets/**` (grid, rich text, info box, header, summary) | `domain/components` + `pw_mapper` | ✅ |
| 12 | `components/widgets/pdf_barcode`, `pdf_digital_signature` | `pdf.barcode(...)`/`pdf.qr(...)` + `pdf.signatureBlock(...)` factories | 🟨 (dedicated visual mapper future) |
| 13 | `components/widgets/pdf_watermark` | `syncfusion_pdf_processor` (watermark op) | ✅ |
| 14 | `infrastructure/generation`, `platform/**`, `processing` | `infrastructure/rendering/**`, `platform/**` | ✅ |
| 15 | `presentation/controllers`, `views/pdf_preview` | `presentation/builder_controller` | 🟨 (preview widget deferred) |
| 16 | `printing/**` (discovery, settings, preview) | `domain/printing` + `PrintGateway`/`PrinterDiscovery` | ✅ |
| 17 | `public/genius_pdf_client` | `application/pdf_client` (`PdfClient`) | 🟨 renamed API |
| 18 | `services/pdf_service` (legacy) | Superseded by `PdfClient` | 🟨 |
| 19 | `services/pdf_security_service` | `PdfSecurityService` + `SyncfusionPdfSecurityService` (encrypt/unlock, permissions) | ✅ |
| 20 | `services/export/**` (html/image/text/PDF-A) | `PdfExporter` + `SyncfusionPdfExporter` | ✅ |
| 21 | `services/job_management/**` | `application/jobs/**` (decomposed) | ✅ |
| 22 | `sharing/**` (email, bluetooth, app) | `EmailGateway` + `ShareGateway` (`PdfShareTarget` + `shareTo`) | ✅ |
| 23 | `ai/**` (analyzer, layout, image, text) | `PdfIntelligence` + offline `HeuristicPdfIntelligence` | ✅ |
| 24 | `templates/**` (18 business) | `application/templates/business/**` | ✅ |
| 25 | `templates/engine/**` | `application/templates/engine/**` | ✅ |
| 26 | `templates/vouchers/**` (19 subtypes) | `application/templates/business/voucher_templates.dart` (13 voucher types) | ✅ |
| 27 | `example/**` (16 features) | `example/** ` Folio Studio (14 destinations) | 🟨 |

---

## 5. Delivered in 1.0.0 & what remains

The items previously deferred are now **delivered** in 1.0.0, each behind its own
port so the pure layers stay clean:

| Item | Delivered as |
|---|---|
| **Security service** (encryption/permissions) | `PdfSecurityService` + `SyncfusionPdfSecurityService`; `PdfSecurityOptions` (RC4/AES-256, typed permissions, redacted `toJson`). |
| **Export to HTML/Image/Text/PDF-A** | `PdfExporter` + `SyncfusionPdfExporter` (text via extractor, images via `printing` + `image` codecs, HTML self-contained, PDF/A re-emit). |
| **AI module** | `PdfIntelligence` port + offline, dependency-free `HeuristicPdfIntelligence` (counts, script, density, bilingual suggestions). |
| **Bluetooth / app-targeted sharing** | `PdfShareTarget` + `ShareGateway.shareTo`/`availableTargets`; routed through the platform sheet. |
| **Voucher parity** | 13 voucher types via `VoucherTemplateBase` (was payment/receipt only). |

**Still remaining (tracked, honest):**

| Item | Why | Re-entry plan |
|---|---|---|
| **Dedicated barcode/QR & signature *visual* mapper** | The `pdf.barcode/qr/signatureBlock` factories exist; a first-class glyph mapper in `pw_mapper` is still future. | `v1.1.0` infra mapper. |
| **Model-backed intelligence** | The offline heuristic ships today; a network/model adapter is optional. | Inject a custom `PdfIntelligence`. |
| **Strict PDF/A validator conformance** | Current PDF/A export is a best-effort archival re-emit; strict conformance depends on compliant source fonts/color. | Harden with font embedding + color profiles. |
| **AI / security demo *screens* in the example** | The APIs are wired; dedicated Studio destinations are not yet added. | Add example destinations. |

---

## 6. Validation workflow (run on every change)

> This environment authors and documents the package; the commands below are the
> **required local/CI gate** the maintainer runs to satisfy the acceptance criteria.

```bash
cd flutter/super_pdf_generator
dart format --set-exit-if-changed .      # style gate
flutter analyze                          # zero warnings/infos
flutter test                             # domain + jobs + boundary + api-compat + financial
cd example && flutter analyze && flutter test
```

**Green-build definition:** format clean · analyzer clean · all suites pass ·
example compiles · no `src/` type leaks in the public barrel · boundary test
passes (no illegal cross-layer imports).

---

## 7. Public API compatibility statement

The target is a **clean-room re-architecture**, not a symbol-for-symbol rename.
The source's imperative, subclass-based API (`GeniusPdfDocumentBuilder`,
`GeniusPdfClient`, `GeniusPdfResult`) is intentionally re-expressed as an
immutable, data-first API (`pdfDocument()`, `PdfClient`, `Result<T>`). The
mapping is documented symbol-by-symbol in `api_overview` and the interactive
**API Explorer**. Consumers migrate via the documented equivalence table; a thin
compatibility shim is a candidate for `v1.1.0` if drop-in source replacement is
required.

---

## 8. Definition of done (release gate for v1.0.0)

- [ ] Every source module in §4 is ✅, 🟨 (with rationale), or ⬜ (tracked in §5).
- [ ] All acceptance criteria in §3 met.
- [ ] Validation workflow (§6) green locally and in CI.
- [x] Docs complete and cross-linked (README, architecture, migration_notes, api_overview, examples).
- [x] AI skill packs present for all three agents with the seven required files each.
- [x] Final migration report published (Migration Report + API Explorer + SDK Docs).
- [x] `CHANGELOG.md` documents the 1.0.0 release; `pubspec.yaml` at `version: 1.0.0`.

---

*This plan is intentionally exhaustive. Treat every ⬜ as a promise, not an omission.*
