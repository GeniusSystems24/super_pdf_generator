/// Folio — PDF Document SDK (Flutter).
///
/// This is the single intentional public barrel for the library. It mirrors
/// the approved Web/TypeScript design: one factory, one fluent builder, one
/// `pdf` component namespace, immutable domain models, discriminated states
/// and typed failures.
///
/// Dependency direction (enforced by test/architecture/boundary_test.dart):
///
///   Presentation → Application → Domain
///   Infrastructure → Application contracts
///   Composition root → all concrete implementations
///
/// The Domain and Application layers are pure Dart — they never import Flutter,
/// `dart:ui`, `dart:io`, the `pdf` package or the `printing` package.
library;

// ---- Domain: models & value objects --------------------------------------
export 'src/domain/value_objects.dart';
export 'src/domain/theme.dart';
export 'src/domain/components.dart';
export 'src/domain/document.dart';
export 'src/domain/document_info.dart';
export 'src/domain/generation.dart';
export 'src/domain/processing.dart';
export 'src/domain/printing.dart';
export 'src/domain/jobs.dart';
export 'src/domain/sharing.dart';
export 'src/domain/security.dart';
export 'src/domain/export.dart';
export 'src/domain/intelligence.dart';

// ---- Domain: financial (audit-grade money, rounding, validation) ----------
export 'src/domain/financial/financial.dart';

// ---- Domain: result & typed failures --------------------------------------
export 'src/domain/failures.dart';

// ---- Application: contracts (ports) ---------------------------------------
export 'src/application/contracts.dart';

// ---- Application: fluent builder + component factory ----------------------
export 'src/application/builder.dart';

// ---- Application: declarative business templates --------------------------
export 'src/application/templates/templates.dart';

// ---- Application: use cases ------------------------------------------------
export 'src/application/usecases.dart';

// ---- Application: intelligence (offline heuristic analyzer) ---------------
export 'src/application/intelligence.dart';

// ---- Application: job management (composed collaborators) -----------------
export 'src/application/jobs/queue_policy.dart';
export 'src/application/jobs/job_repository.dart';
export 'src/application/jobs/retry_policy.dart';
export 'src/application/jobs/scheduler.dart';
export 'src/application/jobs/progress_reporter.dart';
export 'src/application/jobs/queue_statistics.dart';
export 'src/application/jobs/job_queue.dart';

// ---- Application: high-level client ---------------------------------------
export 'src/application/pdf_client.dart';

// ---- Presentation: framework-facing controllers (presentation models) ----
export 'src/presentation/builder_controller.dart';

// ---- Composition root ------------------------------------------------------
export 'src/composition/composition_root.dart';

// ---- Reports: pixel-faithful GeniusLink report documents ------------------
// A self-contained module (fonts + theme + reusable components + document
// builders) that reproduces the reference financial reports — tax invoice,
// trial balance, customer statement and inventory valuation — with full
// LTR/RTL parity. Entry point: `GeniusReports.load()`.
export 'src/reports/reports.dart'hide TrialBalanceData, CustomerStatementData, InventoryItem, InventoryReportData;
