# Work-life provenance

This directory holds small provenance files for the occupational-disease analysis.

- `provenance.yml` is written by `scripts/acquire_worklife.R` after the zip checksum matches the pin.
- `audit/` is written by `scripts/audit_worklife_denominator.R`. It stores the StatFin query, response, metadata and comparison. The offline report reads these files and does not call StatFin.

The zip itself stays in gitignored `data/raw/worklife/`.
