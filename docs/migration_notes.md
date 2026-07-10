# Migration Notes — source → `super_pdf_generator`

> Shared across skill packs. Use this to reason about parity with the source
> package and to avoid re-introducing patterns the target intentionally replaced.

## 1. Source lineage (what the target inherits)

The source `genius_link_pdf_generator` (v3.7.0) grew through a long version
history — charts, watermarks/security, template families, a v2 restructure,
an AI module, advanced printing, unified sharing, a precise position engine,
grid/summary/chart/header refinements. The target adopts the **capabilities**
of that lineage while replacing several **mechanisms** (see §3).

## 2. Public API mapping (imperative → data-first)

| Source (imperative) | Target (data-first) | Note |
|---|---|---|
| `GeniusPdfDocumentBuilder` (subclass, override `build()`, `addLine()`) | `pdfDocument()` fluent builder + `pdf.*` factory | document is immutable data |
| `GeniusPdfReportComposer` | `pdfDocument().content([...])` | same fluent intent |
| `GeniusPdfClient` / `GeniusPdfService` | `PdfClient` | one facade |
| `GeniusPdfResult` (`Success`/`Failure`) | `Result<T>` (`Ok`/`Err`) + `sealed PdfFailure` | typed, retryable, bilingual |
| `GeniusPdfCompositionRoot.defaults` | `createPdfClient()` / `createStudioClient()` | explicit wiring |
| `GeniusPdfGenerationManager` | `client.jobs` (composed queue) | decomposed collaborators |
| `GeniusPdfDataGrid` etc. (draw-on-page widgets) | `pdf.table(...)` + `pw_mapper` | domain node + mapper |
| `templates/**` (18 business + vouchers) | `application/templates/business/**` (18) | engine + registry preserved |
| `syncfusion_pdf_document_processor` | `SyncfusionPdfProcessor` behind processor port | lossless merge/split/rotate/watermark |
| `printing/**` discovery+settings | `PrintGateway` + `PrinterDiscovery` + `PrintSettings` | preserved |
| `sharing/**` (email/bluetooth/app) | `ShareGateway` + `EmailGateway` | bluetooth/app-target deferred |
| `ai/**`, `services/export/**`, `services/pdf_security_service` | — | deferred modules (see below) |

## 3. Mechanisms intentionally replaced

- **Subclass-and-mutate builder → immutable fluent data.** The source builds by
  mutating a stateful builder (`currentY`, `addLine`). The target builds a value
  and renders it, so generation is isolate-safe and testable without a page.
- **Thrown/ambiguous results → `Result<T>` + `sealed PdfFailure`.** No
  expected-condition exceptions.
- **God-class generation manager → composed job collaborators** (policy, repo,
  retry, scheduler, progress, statistics, queue).
- **v2 cache/DI/event/plugin subsystems → plain Clean Architecture.** Their
  intent (extensibility, DI) is met by ports + the composition root, so the
  extra machinery is not carried over.

## 4. Deferred parity (tracked, not dropped)

`AI module`, `barcode/QR components`, `digital signature`, `security service`,
`export to HTML/Image/Text/PDF-A`, `bluetooth/app-targeted sharing`, and the
remaining voucher subtypes are **deferred** to `v1.1.0`/`v1.2.0` behind new
ports so they never pollute the pure layers. See
`development_plan_v1.0.0.md` §5 for the re-entry plan.

## 5. Compatibility expectations

- This is a **clean-room re-architecture**, not a symbol-for-symbol drop-in. A
  source consumer migrates by following the mapping table in §2 and the
  interactive **API Explorer**.
- A thin compatibility shim (source names delegating to target facade) is a
  candidate for `v1.1.0` if a true drop-in is required.
- SemVer: the public barrel is the contract. Breaking it requires a major bump
  and a migration note.

## 6. Common mistakes (do not repeat)

- ❌ Importing `pdf`/`printing` from `domain` or `application`. ✅ Keep engines in
  `infrastructure`.
- ❌ Hand-summing totals in a template. ✅ Recompute + validate via
  `GeniusFinancialValidator`.
- ❌ Adding a component that can't `toJson()`. ✅ Every node is serializable.
- ❌ Constructing infrastructure inside a controller. ✅ Inject from the
  composition root.
- ❌ Throwing for an expected failure. ✅ Return `Err(PdfFailure(...))`.
- ❌ Rasterizing to merge/split. ✅ Use the lossless Syncfusion processor.
- ❌ Rendering Arabic with a standard PDF font. ✅ Register a TTF via
  `FontRegistry`.
