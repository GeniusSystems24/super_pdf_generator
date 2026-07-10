# Best Practices — OpenCode

Focus: **high-performance, workspace-aware, minimal-context** editing.

## Navigate, don't read everything

- Start from the public barrel and the jump table in `README.md`. Grep for the
  symbol; open only the owning file and its test.
- Trust the folder path for the layer rule instead of re-deriving architecture.

## Keep edits minimal and safe

- Smallest possible span; no drive-by reformatting.
- Reuse existing types (`PdfPageSize`, `Result<T>`, gateways) — never fork a
  parallel type for convenience.
- One analyzer/format pass at the end of a batch, not per line.

## Respect the invariants (they prevent expensive rework)

- Domain/application stay Flutter- and engine-free; only `infrastructure/` imports
  `pdf`/`printing`/`syncfusion_flutter_pdf`.
- Documents remain serializable (`toJson()` round-trips).
- Expected failures are `Err(PdfFailure(...))`, not exceptions.
- Totals come from `GeniusFinancialValidator`, not hand math.

## Performance defaults

- Use the isolate runner and lossless processor already wired in the composition
  root. Don't introduce rasterize-to-process shortcuts.
- Fonts: register once via `FontRegistry`, reuse bytes.

## Common mistakes to avoid

- Reading whole layers when a grep + single-file edit would do.
- Adding a new file when an existing one is the right home.
- Touching the public barrel without updating `api_compat_test.dart`.
- Losing Arabic/RTL parity in a quick rename.
- Leaving the gate red "to fix later".
