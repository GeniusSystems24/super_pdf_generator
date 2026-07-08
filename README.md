# Folio — PDF Document SDK (Flutter)

`super_pdf_generator` is the **Flutter implementation** of Folio: a
framework-independent, typed PDF document SDK. It is the Dart sibling of the
approved Web + TypeScript design, preserving the same product identity,
information architecture, component terminology, user flows, design tokens,
public-API philosophy and architecture principles.

> **The library is the product.** The `example/` app (**Folio Studio**) exists
> to exercise and demonstrate the public API — it is a reference integration,
> not a no-code tool.

---

## Architecture

Clean Architecture. Dependencies point inward; the domain and application
layers are **pure Dart** — no Flutter, no plugins, no `pdf`/`printing`.

```
Presentation ─▶ Application ─▶ Domain
Infrastructure ─▶ Application contracts (ports)
Composition root ─▶ all concrete implementations
```

```
lib/
├── super_pdf_generator.dart          # the canonical public barrel
├── pdf_generator.dart                # convenience alias (re-exports the barrel)
└── src/
    ├── domain/                        # immutable models, value objects, typed
    │                                  #   failures + Result, theme, components
    ├── application/
    │   ├── contracts.dart             # ports: PdfRenderer, gateways, logger, fonts
    │   ├── builder.dart               # pdfDocument() fluent builder + `pdf.*` factory
    │   ├── usecases.dart              # GenerateDocument, ProcessDocument
    │   ├── pdf_client.dart            # the high-level PdfClient facade
    │   └── jobs/                       # queue collaborators (NOT one god class):
    │       ├── queue_policy.dart       #   ordering strategy
    │       ├── job_repository.dart     #   storage port + in-memory default
    │       ├── retry_policy.dart       #   retry + backoff strategy
    │       ├── scheduler.dart          #   "is this job due?"
    │       ├── progress_reporter.dart  #   per-job progress streams
    │       ├── queue_statistics.dart   #   derived KPIs
    │       └── job_queue.dart          #   the concurrency-limited executor
    ├── infrastructure/
    │   ├── rendering/
    │   │   ├── pw_mapper.dart          # pure pdf-package mapper (isolate-safe)
    │   │   ├── widget_pdf_renderer.dart# PdfRenderer impl (render + process)
    │   │   └── isolate_render_runner.dart # off-main-isolate generation + fallback
    │   ├── platform/platform_gateways.dart # print / share / file via `printing`
    │   └── support.dart               # loggers + in-memory font registry
    ├── presentation/
    │   └── builder_controller.dart    # presentation model (ChangeNotifier)
    └── composition/
        └── composition_root.dart      # createPdfClient / createStudioClient
```

The demo app is **feature-first**:

```
example/lib/
├── main.dart
├── app/        # StudioApp (owns the client) · StudioShell · StudioTheme
├── shared/     # GeniusLink tokens + reusable widgets (gl_tokens, gl_widgets)
└── features/   # dashboard · builder · preview · processing · batch · jobs ·
                #   settings · reference (components, rtl, errors, performance, templates, api)
```

### Enforced boundary rules — `test/architecture/boundary_test.dart`

- Domain never imports Flutter, `dart:ui`, `dart:io`, `pdf` or `printing`.
- Application never imports Flutter or those plugins either.
- Infrastructure is the **only** layer that imports the `pdf` engine.
- Controllers never construct infrastructure — everything is injected at the
  composition root.

---

## Web → Flutter adaptation map

| Web (TypeScript)              | Flutter (Dart)                                            |
|-------------------------------|-----------------------------------------------------------|
| React components              | Flutter widgets (`example/lib/features/**`)               |
| React hooks / controllers     | Presentation models (`ChangeNotifier`) — `BuilderController` |
| Browser adapters              | Platform adapters (`infrastructure/platform/**`)          |
| Web Workers                   | Dart isolates (`infrastructure/rendering/isolate_render_runner.dart`) |
| Serializable build source     | `PdfDocumentDefinition.toJson()` crosses the isolate boundary |
| Blob download                 | `FileGateway` (default: share-pdf via `printing`)         |
| Browser print                 | `PrintGateway` via `printing` (falls back to platform dialog) |
| Browser share                 | `ShareGateway` via `printing`                             |
| Responsive web layout         | Adaptive `LayoutBuilder` / `MediaQuery` breakpoints (rail collapses < 1080) |
| Keyboard shortcuts            | `Shortcuts` + `Actions` (extension point)                 |
| Web accessibility (ARIA)      | `Semantics`                                               |
| `jsPDF` / web-canvas renderer | `pdf` package behind the `PdfRenderer` port               |
| Typed failure union           | `sealed class PdfFailure` + `Result<T>` (`Ok`/`Err`)      |

---

## Quick start

```dart
import 'package:super_pdf_generator/super_pdf_generator.dart';

// The composition root wires the concrete adapters once (isolate renderer +
// platform print/share/file gateways).
final client = createStudioClient();

// Fluent, immutable document definition — data, so it is isolate-serializable.
final invoice = pdfDocument()
    .metadata(title: 'Invoice INV-2042', author: 'GeniusLink')
    .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.portrait, marginsAll: 32)
    .content([
      pdf.heading('Invoice'),
      pdf.paragraph('Generated from structured business data.'),
      pdf.table(
        columns: const ['Description', 'Qty', 'Amount'],
        rows: const [
          ['Design system license', '1', '1,200'],
          ['Integration support', '12', '1,800'],
        ],
        zebra: true,
      ),
      pdf.statusBadge(label: 'AWAITING PAYMENT', tone: 'orange'),
    ])
    .build();

final result = await client.generate(
  PdfGenerationRequest(fileName: 'invoice.pdf', document: invoice),
);

// Typed outcome — never a thrown exception for expected conditions.
result.fold(
  (ok) => client.download(ok),          // or client.printDocument(ok) / client.share(ok)
  (failure) => print('${failure.code}: ${failure.message} · retryable=${failure.retryable}'),
);
```

### Background & batch

```dart
// Enqueue one job (priority + optional schedule) …
client.enqueue(request, priority: PdfJobPriority.high);

// … or a whole batch, then watch the live queue.
final batchId = client.generateBatch(PdfBatchRequest(requests: many, label: 'statements'));
client.jobs.watch().listen((jobs) => /* update UI */);
client.jobs.stats();   // QueueStatistics: pending/running/completed/failed/avg
```

### Processing

```dart
final merged = await client.process(PdfMergeRequest(inputs: [a, b]));
final stamped = await client.process(PdfWatermarkRequest(input: a, text: 'CONFIDENTIAL', opacity: 0.12));
```

### Custom adapters (extensibility)

Implement a small port and inject it — the core only ever sees the interface:

```dart
class MyRenderer implements PdfRenderer { /* render() + process() */ }

final client = createPdfClient(
  renderer: MyRenderer(),
  logger: const ConsolePdfLogger(),
  concurrency: 8,
);
```

---

## Run the demo (Folio Studio)

```bash
cd flutter/super_pdf_generator/example
flutter pub get
flutter run          # or: flutter run -d chrome / macos / windows
```

The 14 destinations mirror the approved Web IA: Dashboard · Document Builder ·
Component Gallery · PDF Preview · Printing · PDF Processing · Batch Generation ·
Job Manager · RTL & Localization · Error Handling · Performance · Templates ·
API Reference · Settings. Generation, preview, print, share and all processing
operations run for real via the `pdf` + `printing` adapters.

## Testing

```bash
cd flutter/super_pdf_generator
flutter pub get
flutter test
```

| Suite                                   | What it guards                                        |
|-----------------------------------------|-------------------------------------------------------|
| `test/domain/domain_test.dart`          | builder, JSON round-trip, validation, failure taxonomy|
| `test/application/job_queue_test.dart`  | run / retry-with-backoff / cancel / priority ordering |
| `test/architecture/boundary_test.dart`  | layer import rules (executable dependency cruiser)    |
| `test/public_api/api_compat_test.dart`  | public surface + discriminated unions compile & behave|

---

## Design tokens

Two independent token systems (as in the Web proposal):

- **Document theme** (`PdfTheme` / `PdfPalette` in `domain/theme.dart`) — what
  renders *inside* the PDF. RTL, branded and light variants; Latin + Arabic
  font families.
- **UI theme** (`example/lib/shared/gl_tokens.dart`) — the GeniusLink language
  for Studio's chrome (dark-first, electric-blue accent, mono numerics). Never
  leaks into the document.

## Status

Phase Two. The library is feature-complete for the approved scope; the demo
exercises every public API. Font embedding for full Arabic shaping is wired
through `FontRegistry` (register TTF bytes via `createStudioClient(arabicFontBytes: …)`).
