# API Overview — `super_pdf_generator`

> The public surface is the contract. Everything here is exported from the single
> barrel `package:super_pdf_generator/super_pdf_generator.dart` (the
> `pdf_generator.dart` alias re-exports it). Nothing under `src/` is public.

## 1. The one object you hold: `PdfClient`

```dart
import 'package:super_pdf_generator/super_pdf_generator.dart';

final client = createStudioClient(); // or createPdfClient() for the lean core
```

| Method | Returns | Purpose |
|---|---|---|
| `generate(PdfGenerationRequest)` | `Future<Result<PdfBytes>>` | Render a document to bytes (optionally off-isolate). |
| `process(PdfProcessingRequest)` | `Future<Result<PdfBytes>>` | Lossless merge / split / extract / rotate / watermark. |
| `inspect(PdfBytes)` | `Future<Result<PdfInspection>>` | Page count, metadata, per-page geometry — no render. |
| `printDocument(bytes, {settings, printer})` | `Future<Result<void>>` | Print through the platform gateway. |
| `listPrinters()` | `Future<List<PrinterDevice>>` | Enumerate printers. |
| `share(bytes, {subject})` | `Future<Result<void>>` | System share sheet. |
| `email(bytes, {to, subject, body})` | `Future<Result<void>>` | Compose an email with the PDF attached. |
| `download(PdfBytes)` | `Future<Result<void>>` | Persist / open via the file gateway. |
| `enqueue(request, {priority})` | `String` (job id) | Queue a background job. |
| `generateBatch(PdfBatchRequest)` | `String` (batch id) | Queue many jobs. |
| `jobs` | `JobQueue` | `watch()` stream + `stats()` + `cancel(id)`. |

## 2. Building a document: `pdfDocument()` + `pdf.*`

```dart
final doc = pdfDocument()
    .metadata(title: 'Invoice INV-2042', author: 'GeniusLink')
    .theme(const PdfTheme(direction: PdfTextDirection.rtl))
    .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.portrait, marginsAll: 32)
    .content([
      pdf.reportHeader(titleEn: 'Invoice', titleAr: 'فاتورة'),
      pdf.paragraph('Structured, validated business data.'),
      pdf.table(columns: const ['Item', 'Qty', 'Amount'], rows: rows, zebra: true),
      pdf.summary(entries: totals),
      pdf.statusBadge(label: 'AWAITING PAYMENT', tone: 'orange'),
    ])
    .build(); // -> PdfDocumentDefinition (immutable, toJson-able)
```

**Component factory (`pdf.*`):** `heading`, `paragraph`, `richText`, `table`,
`summary`, `infoBox`, `reportHeader`, `statusBadge`, `image`, `divider`,
`spacer`, `list`. Deferred: `pdf.barcode` / `pdf.qr` (v1.1.0).

## 3. Results & failures — always typed

```dart
final result = await client.generate(request);
result.fold(
  (bytes) => client.download(bytes),
  (failure) => log('${failure.code}: ${failure.message} / ${failure.messageAr}'),
);
```

- `Result<T>` = `Ok<T>(value)` | `Err<T>(failure)`.
- `sealed PdfFailure` variants carry `code`, `message`, `messageAr`, `retryable`.
- Expected failures never throw; only contract violations do.

## 4. Domain value objects (pure, immutable)

`PdfPageSize` · `PdfPageOrientation` · `PdfMargins` · `PdfColor` · `PdfAlignment`
· `PdfTheme` / `PdfPalette` · `PdfImage` · `PdfDocumentDefinition` ·
financial: `GeniusMoney`, `GeniusRoundingPolicy`, `GeniusFinancialValidator`.

## 5. Templates

```dart
final registry = defaultTemplateRegistry();
final template = registry.byId('tax_invoice');
final built = template.buildChecked(invoiceData, context: PdfTemplateContext(language: 'ar'));
```

18 built-in templates across Financial / Sales / HR / Vouchers. Each recomputes
and validates totals before building, and honours `context.language` for RTL and
Arabic labels + amount-in-words.

## 6. Jobs & batch

```dart
final id = client.enqueue(request, priority: PdfJobPriority.high);
client.jobs.watch().listen((snapshot) => updateUi(snapshot));
final stats = client.jobs.stats(); // pending / running / completed / failed / avgMs
client.jobs.cancel(id);
```

## 7. Printing

```dart
final printers = await client.listPrinters();
await client.printDocument(
  bytes,
  settings: PrintSettings.highQuality().copyWith(copies: 2, duplex: Duplex.longEdge),
  printer: printers.firstWhere((p) => p.isDefault),
);
```

## 8. Composition & extension points

- `createPdfClient({renderer, printGateway, shareGateway, emailGateway, fileGateway, logger, fontRegistry})`
  — inject your own adapters.
- `createStudioClient(...)` — adds Syncfusion inspection/processing.
- Ports you can implement: `PdfRenderer`, `PdfInspector`, `PrintGateway`,
  `ShareGateway`, `EmailGateway`, `FileGateway`, `PdfLogger`, `JobQueue`.

## 9. What is *not* public

`pdf`, `syncfusion_flutter_pdf`, and `printing` types never appear in the barrel.
They live behind ports in `infrastructure/`. If you find yourself importing one
in application code, that's a boundary violation
(`test/architecture/boundary_test.dart` will fail).
