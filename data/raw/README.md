# data/raw

Place raw input data here. Contents are gitignored.

- **Purpose**: Store source data before processing
- **Next steps**: Add data ingestion logic in `R/` or `_targets.R`
- **Note**: Use synthetic data in `data/synthetic/` for the pediatric example
- **Worklife snapshot**: `make worklife-acquire` stores the verified occupational-disease zip in `data/raw/worklife/`. That file stays gitignored.
