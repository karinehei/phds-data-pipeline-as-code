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

> **Note:** If `renv.lock` has empty `Packages`, run `make setup` to install deps. TODO: Run `renv::snapshot()` after installing to pin versions for reproducible builds.

```bash
make setup    # Install deps (renv if renv.lock exists, else minimal pkgs)
make data     # Generate synthetic data → data/synthetic/visits.parquet
make test     # Run testthat unit tests
make report   # Run targets pipeline + render report → output/report.html
make clean    # Remove output/, data/synthetic/*, _targets/
```

| Target | Description |
|--------|-------------|
| `make setup` | Run `renv::restore()` if `renv.lock` exists; install any missing packages (targets, yaml, arrow, quarto, testthat, ggplot2) |
| `make data` | Generate synthetic pediatric visits to `data/synthetic/visits.parquet` |
| `make test` | Run `Rscript run-tests.R` (testthat) |
| `make report` | Run `targets::tar_make()` (pipeline + report) |
| `make clean` | Remove `output/`, `_targets/`, generated data in `data/synthetic/`, stray `report.html` |
| `make k8s-validate` | Run `kubectl kustomize` on base and dev overlay (requires kubectl) |

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
| `.github/workflows/ci.yml` | CI/CD pipeline |

---

## CI/CD

- **On PR and push to `main`**: Checkout → setup R (r-lib/actions) → install deps (`renv::restore` if `renv.lock` exists, else install targets, yaml, arrow, quarto, testthat, ggplot2, lintr) → lint (optional, non-blocking) → tests → `make report` → upload artifacts (`output/report.html`, `data/synthetic/visits.parquet`).
- **On push to `main` only**: Deploy report to GitHub Pages (enable Pages in repo Settings → Pages → Source: GitHub Actions).

---

## GitOps Deployment

The `k8s/` directory holds Kustomize manifests: a **base** (CronJob, PVCs) and **overlays** (e.g. `dev`) for schedule and image overrides. Argo CD or Flux watches this repo and applies `k8s/overlays/<env>` to the cluster. CronJob runs the pipeline on a schedule, writing outputs to EmptyDir (or PVC in production); no manual `kubectl apply` is required after Git changes.

---

## No Real Patient Data

**This repository contains no real patient or clinical data.** All development and testing use **synthetic data** generated in `R/synthetic_data.R` with fixed seeds (`set.seed()`) for reproducibility. Synthetic datasets mimic schema and distributions for pipeline validation only.

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
