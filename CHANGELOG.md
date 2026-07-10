# Changelog

All notable changes to `super_pdf_generator` (Folio — PDF Document SDK) are
documented here. The format follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## 1.1.0 — 2026-07-10

Additive feature release. New document components render **natively to vector
PDF** (no rasterization) through the pure `pw` mapper, so they stay crisp and
isolate-safe. No breaking changes to the 1.0.0 public surface.

### Added

- **Charts** — `pdf.chart(...)` plus `pdf.barChart` / `lineChart` / `areaChart` /
  `pieChart` and `pdf.series(...)`. New `PdfChart`, `PdfChartSeries`,
  `PdfChartType`. Bar, line, area and pie are drawn with vector primitives
  (`CustomPaint`) and a built-in palette + legends; RTL-aware alignment.
- **Real barcode / QR + signature rendering** — the mapper now renders
  `pdf.barcode(...)` and `pdf.qrCode(...)` as true scannable symbologies via
  `pw.BarcodeWidget` (Code128/39, EAN-13/8, UPC-A, QR, DataMatrix, PDF417),
  replacing the previous placeholders. `pdf.signatureBlock(...)` gained an
  optional `dateLabel` signing line.
- **Watermark & stamp components** — `pdf.watermark(...)` (inline diagonal, tunable
  opacity/angle/size) and `pdf.stamp(...)` (rubber-stamp label, toned bordered
  box, optional date). New `PdfWatermark`, `PdfStamp`. (Distinct from the
  page-background watermark on `PdfPostProcessing`.)
- **Running header / footer with tokens** — `PdfPostProcessing.headerText` /
  `footerText` support `{title} {author} {page} {total} {date} {time}
  {datetime}`, applied per page by the mapper. `pdf.pageNumber(...)` keeps its
  `{page} / {total}` format.
- **Form fields (AcroForm)** — `pdf.textField(...)`, `pdf.checkboxField(...)`,
  `pdf.signatureField(...)`. Empty text fields render as interactive AcroForm
  inputs; filled ones render as static text. New sealed `PdfFormField` family.
- **Fill API** — `FormFiller` use case plus `PdfClient.formFieldNames(doc)` and
  `PdfClient.fillForm(doc, values)`. Pure and immutable — returns a new document,
  reaching into nested containers; String values fill text fields, bool values
  toggle checkboxes.
- **Example (Folio Studio)** — three new EXTEND destinations exercising the
  1.0.0 APIs at runtime: **Security** (encrypt/permissions), **Export**
  (HTML/image/text/PDF-A) and **Intelligence** (analyze + suggestions).
- Tests: `test/domain/components_v11_test.dart` (chart/overlay/form serialization
  + fill API) and expanded `api_compat_test.dart` coverage.

### Changed

- **Version** `1.0.0` → `1.1.0`.
- Added `barcode: ^2.2.8` (infrastructure-only; re-exported by `pdf`, declared
  explicitly as the mapper depends on it directly).

### Notes

- Charts render to vector shapes and are marked for image rasterization only on
  PowerPoint-style exports; in PDF they remain selectable/scalable.
- AcroForm interactivity depends on the viewer; filled values always render as
  visible text so the document reads correctly everywhere.

## 1.0.0 — 2026-07-10

First stable release. Closes the deferred parity items from the migration plan
and brings dependencies up to current stable. The public barrel is now the
committed API contract under SemVer.

### Added

- **Document security** — `PdfSecurityService` port with a Syncfusion adapter
  (`SyncfusionPdfSecurityService`). Encrypt with RC4/AES (up to AES-256), set an
  owner/user password, and grant a typed `PdfDocumentPermission` set.
  `PdfSecurityOptions.toJson()` redacts passwords by design.
  New: `PdfClient.secure()` / `PdfClient.unlock()`.
- **Export pipeline** — `PdfExporter` port with `SyncfusionPdfExporter`
  supporting `PdfExportFormat.html`, `.image` (PNG/JPEG via the `image` codecs),
  `.plainText` (Syncfusion text extraction) and `.pdfA` (A1b/A2b/A3b archival
  re-emit). New: `PdfClient.export()`.
- **Content intelligence** — `PdfIntelligence` port plus a dependency-free,
  offline `HeuristicPdfIntelligence` (wired by default) that reports word/heading/
  table/image/list counts, reading time, script (Latin/Arabic/mixed) and density,
  and emits bilingual layout suggestions. New: `PdfClient.analyze()` /
  `PdfClient.suggestLayout()`.
- **Share targets** — `PdfShareTarget` (system, email, Bluetooth, messaging,
  cloud, print). `ShareGateway` gained `availableTargets` + `shareTo(...)`;
  `PdfClient.shareTo()` routes through the platform sheet (which surfaces
  Bluetooth and installed apps).
- **Voucher family** — twelve new registered voucher templates toward source
  parity: expense, petty cash, journal, contra, bank payment/receipt, cash
  payment/receipt, salary, advance, refund and deposit — each bilingual with
  amount-in-words and net validation, sharing one `VoucherTemplateBase`.
- New failure categories `PdfFailureCategory.security` and `.export`
  (`SecurityFailure`, `ExportFailure`).
- Tests: heuristic intelligence, security/export value types, the voucher
  registry, and expanded public-API compatibility coverage.

### Changed

- **Version** bumped `0.1.0` → `1.0.0`.
- **Dependencies** raised to current stable: `pdf ^3.11.1`, `printing ^5.13.0`,
  `path_provider ^2.1.5`, `meta ^1.15.0`, `url_launcher ^6.3.0`,
  `flutter_lints ^5.0.0`. Added `image ^4.2.0` (infrastructure-only, for the
  export codecs). `syncfusion_flutter_pdf` remains on the reviewed `^32.2.4`
  line.
- **SDK constraints** raised to `sdk: ">=3.6.0 <4.0.0"`, `flutter: ">=3.27.0"`.
- `createStudioClient()` now wires the security service, exporter and heuristic
  intelligence in addition to the renderer, processor, printer discovery and
  email gateway. `createPdfClient()` accepts `security`, `exporter` and
  `intelligence` (defaults to the offline heuristic).

### Architecture

- All new engine work lives in `lib/src/infrastructure` behind ports; the domain
  and application layers stay pure Dart. `test/architecture/boundary_test.dart`
  continues to enforce this.

### Notes / still deferred

- PDF/A export is a best-effort archival re-emit (page templates drawn into a
  conformance-tagged document); strict validator conformance depends on the
  source's fonts/color already being compliant.
- A dedicated visual barcode/QR *component* mapper and a model-backed
  `PdfIntelligence` remain future work; the QR/barcode builder factories and the
  offline analyzer ship today.

## 0.1.0

- Initial migration of the GeniusLink PDF reference into Folio's clean
  architecture: domain, application, infrastructure and composition layers;
  fluent builder + `pdf.*` factory; job queue; 18 business templates; Syncfusion
  processing + inspection; platform gateways; Folio Studio example.
