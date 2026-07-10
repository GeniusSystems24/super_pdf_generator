<!-- Skill pack: ChatGPT Codex — shared project reference (identical across agents by design). -->

# Reusable Implementation Patterns & Examples

> Shared across skill packs. Copy-adapt these recipes; they encode the package's
> conventions so new code matches existing code.

## Quick start

```dart
import 'package:super_pdf_generator/super_pdf_generator.dart';

final client = createStudioClient();

final invoice = pdfDocument()
    .metadata(title: 'Invoice INV-2042', author: 'GeniusLink')
    .page(size: PdfPageSize.a4, orientation: PdfPageOrientation.portrait, marginsAll: 32)
    .content([
      pdf.heading('Invoice'),
      pdf.paragraph('Generated from structured business data.'),
      pdf.table(columns: const ['Description', 'Qty', 'Amount'], rows: rows, zebra: true),
      pdf.statusBadge(label: 'AWAITING PAYMENT', tone: 'orange'),
    ])
    .build();

final result = await client.generate(
  PdfGenerationRequest(fileName: 'invoice.pdf', document: invoice),
);
result.fold((ok) => client.download(ok), (f) => log('${f.code}: ${f.message}'));
```

---

## Pattern: add a PDF template

1. Create `application/templates/business/<name>_template.dart`.
2. Extend `PdfTemplate`; accept a typed data model and a `PdfTemplateContext`.
3. Recompute totals; validate with a `GeniusFinancialValidator` before building.
4. Implement `buildChecked(data, context:)` returning the document only when the
   arithmetic is provably correct; carry validation errors otherwise.
5. Register the id in `defaultTemplateRegistry()`.
6. Honour `context.language` for RTL/Arabic labels and amount-in-words.

```dart
class DeliveryNoteTemplate extends PdfTemplate<DeliveryNoteData> {
  const DeliveryNoteTemplate();
  @override
  TemplateResult buildChecked(DeliveryNoteData data, {required PdfTemplateContext context}) {
    final validation = context.validator.checkColumnSums(data.lines);
    if (!validation.isValid) return TemplateResult.invalid(validation);
    return TemplateResult.ok(_compose(data, context));
  }
}
```

## Pattern: add a component (widget)

1. Add an immutable node to `domain/components.dart` (pure data — no `pdf` import).
2. Expose a factory on the `pdf.*` namespace in `application/builder.dart`.
3. Teach `infrastructure/rendering/pw_mapper.dart` to map the node to a
   `pdf`-package widget. Provide a raster fallback if it can't map.
4. Cover the JSON round-trip in `test/domain`.

## Pattern: add a renderer

1. Implement the `PdfRenderer` port (`render()` + optional `process()`).
2. Keep it pure enough to run in an isolate, or wrap it in `IsolateRenderRunner`.
3. Inject it via `createPdfClient(renderer: MyRenderer())` — the core only sees
   the interface.

## Pattern: register fonts (RTL / Arabic)

```dart
final client = createStudioClient(arabicFontBytes: notoNaskhBytes);
// or, low level:
final registry = FontRegistry()
  ..register('NotoNaskhArabic', regular: regularBytes, bold: boldBytes);
```
- The host app owns the TTF assets. Standard PDF fonts do **not** contain Arabic
  glyphs — always supply a TrueType face for Arabic content.

## Pattern: create a theme

```dart
const theme = PdfTheme(
  palette: PdfPalette.branded(primary: PdfColor(0xFF4A7CFF)),
  direction: PdfTextDirection.rtl,
  latinFamily: 'Inter',
  arabicFamily: 'NotoNaskhArabic',
);
```

## Pattern: support RTL

- Set the document/theme direction to `rtl`.
- Tables mirror column order; report headers use the bilingual split (English
  column left-aligned LTR, Arabic column right-aligned RTL) regardless of the
  global direction.

## Pattern: support Arabic

- Provide Arabic strings (`titleAr`, `labelAr`) and an Arabic TTF via
  `FontRegistry`.
- Use amount-in-words in Arabic for vouchers/invoices.

## Pattern: tables

```dart
pdf.table(
  columns: const ['Item', 'Qty', 'Unit', 'Total'],
  rows: lineItems,
  zebra: true,
  // totals recomputed & validated by the template layer, not hand-summed
);
```

## Pattern: printing

```dart
final printers = await client.listPrinters();
await client.printDocument(bytes,
  settings: PrintSettings(copies: 2, duplex: Duplex.longEdge, color: true),
  printer: printers.firstWhere((p) => p.isDefault),
);
```

## Pattern: preview

- Generate bytes, then hand them to a preview surface. Keep the preview position
  in local state; never block the UI thread on generation (use background mode).

## Pattern: saving

```dart
result.fold((ok) => client.download(ok), (f) => showError(f));
// download() routes through FileGateway (default: share-pdf via printing).
```

## Pattern: exporting (deferred module)

- Export-to-HTML/Image/Text/PDF-A is a planned `PdfExporter` port. Until it
  lands, exporting is out of the core generate/process/print pipeline — do not
  add ad-hoc exporters inside the domain.

## Pattern: background & batch

```dart
client.enqueue(request, priority: PdfJobPriority.high);
final batchId = client.generateBatch(PdfBatchRequest(requests: many, label: 'statements'));
client.jobs.watch().listen(updateUi);
client.jobs.stats(); // pending/running/completed/failed/avg
```
