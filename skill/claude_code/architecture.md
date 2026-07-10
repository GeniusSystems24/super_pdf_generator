<!-- Skill pack: Claude Code — shared project reference (identical across agents by design). -->

# Architecture — `super_pdf_generator` (Folio PDF Document SDK)

> Shared reference for all AI agents. This file describes the *target* package
> architecture. It is identical across skill packs on purpose — every agent
> reasons about the same system.

## 1. One-paragraph model

`super_pdf_generator` is a framework-independent, typed PDF document SDK. A
document is **immutable data** (`PdfDocumentDefinition`) built by a fluent
builder (`pdfDocument()`), turned into bytes by an injected renderer behind a
port, and delivered/processed through platform gateways. The high-level
`PdfClient` facade is the one object application code touches.

## 2. Layers & dependency direction

```
Presentation ─▶ Application ─▶ Domain
Infrastructure ─▶ Application contracts (ports)
Composition root ─▶ wires all concrete implementations
```

- **Domain** (`lib/src/domain/**`) — pure Dart. Immutable models, value objects,
  the document tree, `PdfTheme`/`PdfPalette`, the financial sub-domain
  (`GeniusMoney`, `GeniusRoundingPolicy`, `GeniusFinancialValidator`), and the
  `Result<T>` + `sealed PdfFailure` taxonomy. **Never** imports Flutter,
  `dart:ui`, `dart:io`, `pdf`, or `printing`.
- **Application** (`lib/src/application/**`) — pure Dart. Ports (`contracts.dart`),
  the fluent builder + `pdf.*` component factory, declarative templates, use
  cases (`GenerateDocument`, `ProcessDocument`, `InspectDocument`), the composed
  job queue, and the `PdfClient` facade.
- **Infrastructure** (`lib/src/infrastructure/**`) — the **only** layer allowed
  to import the `pdf`/`syncfusion`/`printing` engines. Renderers, the Syncfusion
  processor, the isolate runner, and platform gateways (print/share/email/file).
- **Presentation** (`lib/src/presentation/**`) — `ChangeNotifier` presentation
  models (e.g. `BuilderController`). No infrastructure construction here.
- **Composition** (`lib/src/composition/**`) — `createPdfClient()` /
  `createStudioClient()` wire the concrete adapters exactly once.

The boundary is **executable**: `test/architecture/boundary_test.dart` fails the
build if any layer imports something it must not.

## 3. Rendering pipeline

```
pdfDocument() ─▶ PdfDocumentDefinition (immutable, toJson-able)
      │
      ▼
PdfClient.generate(request)
      │  (optionally hops to a background isolate)
      ▼
IsolateRenderRunner ─▶ PdfRenderer (widget_pdf_renderer)
      │                     │
      │                     ├─ pw_mapper: Domain component ─▶ pdf-package widget
      │                     └─ raster fallback when a component can't map
      ▼
ProcessingRenderer (decorator) ─▶ SyncfusionPdfProcessor (lossless ops)
      ▼
Result<PdfBytes>  ── fold ─▶ download / print / share / email
```

- **Mapping** is isolate-safe: `pw_mapper` is pure and consumes only serialized
  document data, so generation can run off the main isolate.
- **Processing** (merge/split/extract/rotate/watermark/inspect) is layered on by
  the Syncfusion processor and is *lossless* — text stays selectable.
- **Inspection** (`inspect()`) reads page count, metadata, per-page geometry and
  rotation without rendering.

## 4. Folder structure (target)

```
lib/
├── super_pdf_generator.dart      # canonical public barrel
├── pdf_generator.dart            # convenience alias
└── src/
    ├── domain/{value_objects,theme,components,document,document_info,
    │           generation,processing,printing,jobs,failures}.dart
    │   └── financial/{genius_money,genius_rounding_policy,
    │                  genius_financial_validator,...}.dart
    ├── application/{contracts,builder,usecases,pdf_client}.dart
    │   ├── templates/{engine,support,business}/**
    │   └── jobs/{queue_policy,job_repository,retry_policy,scheduler,
    │             progress_reporter,queue_statistics,job_queue}.dart
    ├── infrastructure/
    │   ├── rendering/{pw_mapper,widget_pdf_renderer,
    │   │              syncfusion_pdf_processor,processing_renderer,
    │   │              isolate_render_runner}.dart
    │   └── platform/platform_gateways.dart
    ├── presentation/builder_controller.dart
    └── composition/composition_root.dart
```

## 5. Dependency rules (enforced)

1. A file under `domain/` imports only `dart:*` (minus `dart:ui`/`dart:io`) and
   other domain files.
2. A file under `application/` imports domain + application only — never
   Flutter, `pdf`, or `printing`.
3. Only `infrastructure/` may import `pdf`, `syncfusion_flutter_pdf`, `printing`,
   `path_provider`, `open_file`, `share_plus`, `url_launcher`.
4. Controllers never `new` an infrastructure type — the composition root injects
   everything.
5. The public barrel exports domain + application + composition only. No `src/`
   infrastructure type is part of the public surface.

## 6. Internal API map (who calls whom)

- `PdfClient` → use cases → ports (`PdfRenderer`, `PdfInspector`, `PrintGateway`,
  `ShareGateway`, `EmailGateway`, `FileGateway`, `JobQueue`, `PdfLogger`,
  `FontRegistry`).
- `pdfDocument()` / `pdf.*` → build a `PdfDocumentDefinition`.
- Templates → `PdfTemplateContext` (+ financial validators) → document.
- Composition root → constructs `IsolateRenderRunner(WidgetPdfRenderer)`,
  `ProcessingRenderer(SyncfusionPdfProcessor)`, and the platform gateways, then
  hands them to `PdfClient`.

## 7. Design tokens (two independent systems)

- **Document theme** (`PdfTheme`/`PdfPalette`) — what renders *inside* the PDF
  (RTL, branded, light; Latin + Arabic families). Lives in the domain.
- **UI theme** — the GeniusLink language for the Studio example's chrome. Never
  leaks into the document.
