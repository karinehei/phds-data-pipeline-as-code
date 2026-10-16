# phds-data-pipeline-as-code

R-based data pipeline for PHDS/PHEMS-style analytics: contract validation, reproducible builds, and Quarto reporting. Designed for **privacy-first** workflows (no real patient data), **reproducible** execution via `targets` and `renv`, and **auditable** outputs for compliance and review.

---

## Overview

This pipeline ingests data, validates it against a schema, runs transformations, and produces an HTML report. It is built for environments where data provenance and auditability matter—e.g., public health or clinical analytics—and where synthetic data must be used for development and demos.

---

## Prerequisites

The pipeline requires **R** (with `Rscript`) and **Quarto**. If you see `Rscript: not found` when running `make setup`, install them first.

### Ubuntu / WSL

```bash
# Add CRAN repository and install R (replace 'jammy' with your Ubuntu codename, e.g. noble for 24.04)
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y 'deb https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/'
sudo apt-get update
sudo apt-get install -y r-base

# Install Quarto
wget -q https://quarto.org/docs/get-started/_download/quarto-linux-amd64.deb -O quarto.deb
sudo dpkg -i quarto.deb
```

Check your Ubuntu codename with `lsb_release -cs` if unsure.

### Other platforms

- **R**: [CRAN](https://cran.r-project.org/)
- **Quarto**: [quarto.org/docs/get-started](https://quarto.org/docs/get-started/)

### "lib is not writable" when running `make setup`

If you see `'lib = "/usr/local/lib/R/site-library"' is not writable` or `unable to install packages`, R is trying to install to a system directory you don't have write access to. Use a user library instead:

```bash
# Create a user-writable R library and use it for this session
mkdir -p ~/R/library
export R_LIBS_USER=~/R/library
make setup
```

To make this permanent, add the `export` line to your `~/.bashrc` or `~/.profile`.

---

## Quick Start

The pinned environment is **R 4.6.1**, the same version declared in `.github/workflows/ci.yml` and recorded in `renv.lock`. `make setup` runs `renv::restore()` and does not install extra packages outside the lockfile. CI restores that lockfile and does not fill gaps with a second package install. Optional lint uses `lintr` only when it is already available; it is not part of the lockfile.

```bash
make setup    # Restore the renv.lock library (R 4.6.1)
make data     # Generate synthetic data → data/synthetic/visits.parquet
make test     # Run testthat unit tests
make report   # Run targets pipeline + render report → output/report.html
make clean    # Remove output/, data/synthetic/*, _targets/
```

| Target | Description |
|--------|-------------|
| `make setup` | Restore the R 4.6.1 library recorded in `renv.lock` |
| `make data` | Generate synthetic pediatric visits to `data/synthetic/visits.parquet` |
| `make test` | Run `Rscript run-tests.R` (testthat) |
| `make report` | Run `targets::tar_make()` (pipeline + report) |
| `make site` | Prepare `_site/` for Pages from the pediatric `output/`, omitting `output/worklife/` |
| `make clean` | Remove `output/`, `_targets/`, generated data in `data/synthetic/`, stray `report.html` |
| `make k8s-validate` | Run `kubectl kustomize` on base and dev overlay (requires kubectl) |
| `make worklife-acquire` | Download the pinned occupational-disease snapshot and keep it only if the size and SHA-256 match |
| `make worklife-audit` | Compare the packaged employment denominator with Statistics Finland table 115s |
| `make worklife` | Build the offline worklife report from the verified snapshot and saved audit |
| `make worklife-clean` | Remove `_targets_worklife/` and `output/worklife/` |

The same worklife steps without GNU make:

```bash
Rscript scripts/acquire_worklife.R
Rscript scripts/extract_worklife_codebook.R
Rscript scripts/audit_worklife_denominator.R
Rscript scripts/build_worklife.R
Rscript run-tests.R
```

---

## Repository Structure

| Path | Purpose |
|------|---------|
| `R/` | Validation, synthetic generation, and pipeline logic |
| `_targets.R` | Pipeline definition and dependency graph |
| `report.qmd` | Quarto HTML report |
| `data_contract/contract.yaml` | Schema for input validation |
| `data/raw/` | Raw input (gitignored) |
| `data/synthetic/` | Generated synthetic data |
| `output/` | Pipeline outputs and reports |
| `docker/` | Container image for pipeline execution |
| `k8s/base/` | CronJob + ConfigMap + EmptyDir; `k8s/overlays/dev/` for environment-specific config |
| `.github/workflows/ci.yml` | CI (lint, test, report, artifacts) + deploy to GitHub Pages on main |

---

## CI/CD

- **On PR and push to `main`**: Checkout → install `libcurl4-openssl-dev` and `libglpk-dev` → setup R 4.6.1 (r-lib/actions) → `renv::restore()` from `renv.lock` → optional lint if `lintr` is present → tests → `make report` → upload artifacts (`output/`, `data/synthetic/visits.parquet`). The worklife report is not built in this job. `libglpk-dev` is required because the locked `igraph` binary, imported by `targets`, loads `libglpk.so.40`.
- **On push to `main` only**: Deploy report to GitHub Pages (enable Pages in repo Settings → Pages → Source: GitHub Actions).

---

## Publishing the report

Enable **Settings → Pages → Source: GitHub Actions**. After pushing to `main`, the report is published at `https://<user>.github.io/<repo>/`.

The report is also available as a CI artifact (`phds-report`) on every run (PR and push)—download it from the Actions run summary. The CI workflow copies `report.html` to `index.html` before deploy so the site root serves the report.

---

## GitOps Deployment

The `k8s/` directory holds Kustomize manifests: a **base** (CronJob, ConfigMap, EmptyDir) and **overlays** (e.g. `dev`) for schedule and image overrides. Argo CD or Flux watches this repo and applies `k8s/overlays/<env>` to the cluster. CronJob runs the pipeline on a schedule, writing outputs to EmptyDir (or PVC in production); no manual `kubectl apply` is required after Git changes.

---

## Working-life analysis

The pediatric example above is unchanged. A second, separate pipeline describes confirmed occupational diseases in Finland.

**Question.** In the released 2019–2023 extract, which two-digit occupations have the most retained confirmed cases, which have the highest employment-normalised five-year values, and how do those rankings change when COVID-19 is separated?

**Source.** Työterveyslaitos / Työelämätieto, dataset *Työikäisten vahvistetut ammattitaudit*, handed over 20 May 2026, licence CC BY 4.0. The pinned file is `occupational-diseases-data-20052026.zip` (292,234 bytes). Employment denominators inside the package come from Statistics Finland table 115s (CC BY 4.0).

**Report.** `output/worklife/report.html` after `make worklife`. CI builds only the pediatric report. `make site` copies that report and leaves out `output/worklife/`.

**Limits.** Each row in file A is one retained case, not one person. Small cells were removed, Åland is absent from the case extract, and only the most severe recorded disease is kept. The ratio is the count of published cases relative to the packaged employment denominator. The saved 16 October 2026 audit found that this denominator matches rounded mean annual employment for 2019–2023, describes ages 18–74, and includes Åland, while the cases are ages 15–64 and exclude Åland. It is not an annual incidence, an individual probability, a causal risk, or a directly comparable population rate. Sampling intervals are not estimated. Files B and C are not joined to file A.

The review of these checks is in `docs/worklife-review.md`.

The plan and the checks behind the pin are in `docs/worklife-analysis-plan.md`.

## No Real Patient Data

**This repository contains no real patient or clinical data.** The pediatric example uses **synthetic data** generated in `R/synthetic_data.R` with fixed seeds (`set.seed()`). The working-life analysis uses a public occupational-disease extract that is downloaded, checksum-verified, and kept out of git. Synthetic pediatric data mimic schema and distributions for pipeline validation only.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Data contract** | Schema-first validation ensures inputs meet expectations before processing; supports compliance and debugging. |
| **targets** | Declarative dependency graph, incremental runs, and clear provenance for reproducible analytics. |
| **Parquet** | Columnar format for efficient I/O and versioning; suitable for analytics workloads. |
| **Deterministic seeds** | `set.seed()` in synthetic generation guarantees reproducible demos and tests. |

---

## License

MIT – see [LICENSE](LICENSE).
