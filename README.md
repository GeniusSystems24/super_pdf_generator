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
    │   │                              #   failures + Result, theme, components,
    │   │                              #   processing, printing, document_info
    │   └── financial/                  # audit-grade money + rounding + validation
    │       ├── genius_money.dart        #   integer-minor-unit Money value object
    │       ├── genius_rounding_policy.dart # rounding modes + tolerance
    │       └── genius_financial_validator.dart # subtotal/VAT/total/balance rules
    ├── application/
    │   ├── contracts.dart             # ports: PdfRenderer, PdfInspector, gateways,
    │   │                              #   PrinterDiscovery, EmailGateway, logger, fonts
    │   ├── builder.dart               # pdfDocument() fluent builder + `pdf.*` factory
    │   ├── templates/                  # declarative business templates (pure Dart)
    │   │   ├── engine/template.dart     #   PdfTemplate + PdfTemplateContext
    │   │   ├── template_registry.dart   #   id → template registry
    │   │   ├── support/                 #   money formatting + amount-in-words (EN/AR)
    │   │   └── business/                #   tax invoice · payslip · trial balance ·
    │   │                                #     account statement · payment voucher
    │   ├── usecases.dart              # GenerateDocument, ProcessDocument, InspectDocument
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
    │   │   ├── widget_pdf_renderer.dart# PdfRenderer impl (render + raster fallback)
    │   │   ├── syncfusion_pdf_processor.dart # LOSSLESS merge/split/rotate/watermark + inspect
    │   │   ├── processing_renderer.dart # decorator: base render + Syncfusion process
    │   │   └── isolate_render_runner.dart # off-main-isolate generation + fallback
    │   ├── platform/platform_gateways.dart # print (+ discovery/settings) / share / email / file
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

## Business templates & audit-grade financial validation

Folio ships a **financial domain** (`domain/financial/`) and a **declarative
template engine** (`application/templates/`) adopted from the GeniusLink PDF
reference and re-expressed against Folio's clean layering — both are **pure
Dart** and stay inside the boundary rules above.

- **`GeniusMoney`** stores value as an integer count of minor units, so
  arithmetic is exact; **`GeniusRoundingPolicy`** controls decimal places,
  rounding mode and tolerance (3-decimal currencies like KWD/BHD supported).
- **`GeniusFinancialValidator`** proves subtotals, VAT, grand totals,
  transfer nets, currency conversions, debit=credit balance, column
  sums/averages and budget variance — every failure carries a bilingual
  (EN/AR) message.
- **Templates** recompute their totals and validate the caller-provided
  figures *before* building; `buildChecked()` returns the document only when
  the arithmetic is provably correct. Amount-in-words (EN/AR) is built in.

```dart
const template = TaxInvoiceTemplate();
final ctx = PdfTemplateContext(roundingPolicy: GeniusRoundingPolicy.forCurrency('SAR'));
final result = template.buildChecked(invoiceData, context: ctx);
if (result.isValid) {
  await client.generate(PdfGenerationRequest(fileName: 'inv.pdf', document: result.document!));
} else {
  for (final e in result.validation.errors) print(e.message); // e.messageAr for Arabic
}
```

Built-ins (also in `defaultTemplateRegistry()`): 30 templates across four
categories —
**Financial**: tax invoice (VAT + QR), trial balance (debit=credit), balance
sheet (assets=liabilities+equity), income statement (margins), cash flow,
budget report (variance %), customer statement (aging), account statement
(running balance), inventory report (stock valuation).
**Sales**: quotation, purchase order, delivery note (ordered vs delivered),
credit note.
**HR**: payslip, employee report, attendance report, leave balance report.
**Vouchers**: payment/receipt, expense, petty cash, journal, contra, bank
payment/receipt, cash payment/receipt, salary, advance, refund, deposit — all
sharing one `VoucherTemplateBase`.
Each honours `PdfTemplateContext`'s language, so Arabic output is RTL with
Arabic labels and amount-in-words.

## Lossless PDF processing & introspection

`createStudioClient()` layers a **Syncfusion-backed** processor over the
generation pipeline. Unlike the rasterize-and-recompose fallback, merge /
split / extract / rotate / watermark are now **lossless** — text stays
selectable, vectors stay sharp and files stay small. `client.inspect(input)`
returns a `PdfDocumentInfo` (page count, metadata, per-page geometry and
rotation) without rendering.

## Printing, discovery & delivery

`PrintGateway.printDocument` now takes optional `PrintSettings` (copies,
colour, duplex, paper size, page ranges) and a target `PrinterDevice`;
`client.listPrinters()` enumerates devices via `PrinterDiscovery`, and
`client.emailCompose(...)` opens a pre-filled email. `client.shareTo(...)`
routes to a `PdfShareTarget` (system, email, Bluetooth, messaging, cloud,
print), and `client.availableShareTargets` reports what the platform sheet
exposes; `client.share(...)` opens the full sheet (Bluetooth + installed apps).

## Security, export & intelligence (1.0.0)

`createStudioClient()` also wires document security, an export pipeline and an
offline content analyzer — each behind its own port, engines in infrastructure.

- **Security** — `client.secure(...)` encrypts (RC4 / AES up to AES-256) with an
  owner/user password and a typed `PdfDocumentPermission` set;
  `client.unlock(...)` removes protection given the password.
  `PdfSecurityOptions.toJson()` redacts passwords by design.
- **Export** — `client.export(...)` converts an existing PDF to HTML, raster
  images (PNG/JPEG), plain text, or PDF/A (A1b/A2b/A3b).
- **Intelligence** — `client.analyze(...)` returns a `PdfContentAnalysis`
  (word/heading/table/image counts, reading time, script, density) and
  `client.suggestLayout(...)` returns bilingual `PdfLayoutSuggestion`s. The
  default `HeuristicPdfIntelligence` runs entirely offline — no network, no
  model; inject your own `PdfIntelligence` for a smarter analyzer.

```dart
final locked = await client.secure(PdfSecurityRequest(
  input: PdfInputFile(name: 'inv.pdf', bytes: bytes),
  options: const PdfSecurityOptions(userPassword: 'open-sesame'),
));
final pages = await client.export(PdfImageExportRequest(
  input: PdfInputFile(name: 'inv.pdf', bytes: bytes), dpi: 150));
final analysis = await client.analyze(invoice); // Result<PdfContentAnalysis>
```

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
| `test/domain/security_export_test.dart` | security + export value types (redaction, formats)    |
| `test/application/job_queue_test.dart`  | run / retry-with-backoff / cancel / priority ordering |
| `test/application/intelligence_test.dart`| offline analyzer counts, script detection, suggestions|
| `test/application/templates_test.dart`  | voucher-family registry + a template builds           |
| `test/architecture/boundary_test.dart`  | layer import rules (executable dependency cruiser)    |
| `test/public_api/api_compat_test.dart`  | public surface + discriminated unions compile & behave|

---

## Reports — pixel-faithful GeniusLink documents

Alongside the generic document-tree renderer, the SDK ships a self-contained
**reports module** (`lib/src/reports/`, re-exported from the main barrel) that
reproduces the reference financial documents — **Tax Invoice**, **Trial
Balance**, **Customer Statement** and **Inventory Valuation Report** — with full
**LTR / RTL (English / Arabic) parity**. It renders directly on the `pdf` widget
layer for exact control over the reference layouts, and bundles its own fonts
(Noto Sans + Noto Naskh Arabic) so Arabic shaping works with no setup.

```dart
import 'package:super_pdf_generator/super_pdf_generator.dart';

final reports = await GeniusReports.load();           // decodes bundled fonts

// Generate any document, in either direction, from your data (or the samples):
final bytes = await reports.taxInvoice(
  ReportSamples.taxInvoice(),
  dir: ReportDir.rtl,
);

await Printing.layoutPdf(onLayout: (_) => bytes);      // print / share / save
```

### What's in the box

- **Theme** — `ReportPalette` (the exact reference fills: `#e0e0e0` table
  headers, `#f5f5f5` zebra rows, `#e3f2fd` group bands, `#424242` grand-total
  band, plus green / red / gray summary tints), `ReportTypeScale`,
  `ReportFonts`, and `ReportTheme` which composes them with a reading direction
  and hands out ready-made text styles + mirroring helpers.
- **Reusable components** — `CompanyHeader` (bilingual, logo slot),
  `DocumentTitle`, `InfoSection` (two mirrored key/value panels),
  `ReportDataTable` (grouped, zebra-striped, subtotals + dark grand-total band,
  paginates row-by-row via `.widgets()`), `TotalsPanel`, `SummaryBox`
  (invoice / card / bordered / minimal presets with semantic subtotal tints),
  `SignatureRow`, `NotesBlock`, `QrPanel`, `PageFooter` (running user · date ·
  page band).
- **Document builders** — `TaxInvoiceReport`, `TrialBalanceReport`,
  `CustomerStatementReport`, `InventoryValuationReport`, each taking a typed
  data object and a `ReportDir`.
- **Facade + samples** — `GeniusReports` (one entry point) and `ReportSamples`
  (data mirroring the reference PDFs, for a one-call identical document).

### RTL behaviour

Set `dir: ReportDir.rtl` and the module mirrors column order, flips label/value
placement, moves the currency code to the leading side (`SAR 30,100.00` vs
`30,100.00 SAR`), and renders the Arabic label of every field/title/column.
Bilingual company details keep English-left / Arabic-right in both directions,
matching the reference.

### Composing a custom document

The builders are thin; you can assemble your own from the same components and
hand the flat widget list to `ReportDocument.render(theme: …, body: […])`. Use
`reports.themeFor(dir)` to get the composed `ReportTheme`.

### The example screen

`example/lib/features/reports/reports_screen.dart` ("Report Library", the
studio's landing destination) demonstrates the whole module: a GeniusLink-styled
document picker, an **LTR / RTL** toggle, a live `PdfPreview` (print & share from
its toolbar) and a per-document usage snippet. Run it with `flutter run` from
`example/`.

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

**1.0.0 — stable.** The public barrel is the committed API contract under SemVer.
The library is feature-complete for the approved scope plus the 1.0.0 additions
(document security, export pipeline, offline content intelligence, the full
voucher family and share targets); the demo exercises the core public API. Font
embedding for full Arabic shaping is wired through `FontRegistry` (register TTF
bytes via `createStudioClient(arabicFontBytes: …)`). See `CHANGELOG.md`.
