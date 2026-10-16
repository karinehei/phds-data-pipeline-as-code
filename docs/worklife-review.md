# Working-life analysis review

Review date: 16 October 2026. Branch: `feature/worklife-occupational-diseases`. No push, merge, or deployment was made from this review. GitHub Actions was not re-run after the `libglpk` fix below.

## Findings and fixes

The saved StatFin audit (`data/worklife/audit/audit.yml`, retrieved `2026-10-16T13:27:17Z`) already separated three facts:

- Arithmetic: all 43 packaged occupation codes match 2019–2023 mean employment rounded to the nearest thousand. The packaged denominator was not replaced.
- Source definitions: cases are described as ages 15–64 and exclude Åland. Table 115s has no age variable. The fetched employment documentation defines employed people as ages 18–74. Regional totals matched the whole country, so that denominator includes Åland.
- Comparability: the numerator and denominator do not describe the same age range or the same area. The ratio is the count of published retained cases relative to the packaged employment denominator. It is not an individual risk, an annual incidence, or a directly comparable population rate.

Those statements were present in the interpretation section but not in the Finnish summary or the ratio figure. They are now in the executive summary, the methods section, figure 2 (image caption and HTML caption), the rank-figure note, and the interpretation. The live StatFin query was not repeated.

Rankings are computed before display rounding, with `ties.method = "min"`. Count ranks cover occupations present in the released extract. Ratio ranks cover only those occupations with a positive packaged denominator. A fresh integrity script on the verified zip confirmed 6,096 rows, 2,940 exact `COVID-19-infektio` rows, repeated rows kept, occupation `01` preserved, unique denominator keys, undefined ratios for ZZ and for a zero denominator, absent occupations left as missing counts, occupation 53 at count rank 1 and ratio rank 4 (1,496 cases, ratio 7.632653), and occupation 61 at ratio rank 1 (591 cases, 0 COVID-19, ratio 13.43182). Occupations 53 and 81 share the other-diagnosis count 258 and the same rank.

`renv.lock` records R 4.6.1. `.github/workflows/ci.yml` requests R 4.6.1. That pairing was already consistent. CI had a second step that installed any missing R package after restore, which would hide an incomplete lockfile. That step now fails if `renv.lock` is absent, and it no longer installs extra packages. `make setup` only bootstraps `renv` if needed and then runs `renv::restore()`.

The first GitHub Actions restore of this lockfile failed while loading `igraph` 2.3.4: `libglpk.so.40` was missing. `targets` imports `igraph`. The workflow now installs `libglpk-dev` together with `libcurl4-openssl-dev`. This review did not re-run Actions, so that fix is unverified in CI.

`make site` now omits `output/worklife/` from the Pages staging directory. The Pages job itself is unchanged and still publishes the pediatric `output/` artifact from `make report`.

`_targets/meta/meta` in commit `07b0f8a` contained only targets bookkeeping from running the pediatric pipeline after the worklife modules existed: new function hashes and updated plot, validation, and report rows. The pre-feature version from `a0876a9` is restored in the working tree. That does not rewrite the commit. The pre-existing uncommitted metadata that was already dirty at the start of implementation had been overwritten by that pipeline run before the commit, so it could not be recovered separately. No analysis source was reverted.

## Commands and environments

Windows, R 4.6.1, Quarto 1.10.19, project renv library:

```text
Rscript C:\Users\karin\AppData\Local\Temp\worklife_integrity.R
Rscript run-tests.R
Rscript scripts/build_worklife.R
```

The integrity script reported `integrity ok`. `run-tests.R` passed the pediatric and worklife tests. `scripts/build_worklife.R` rendered `output/worklife/report.html` from the local snapshot and the saved audit. It did not download the zip or query StatFin.

WSL Ubuntu 24.04 has GNU Make 4.3, Quarto, and R 4.3.3. Docker Desktop was installed but the engine was not running. An isolated R 4.6.1 build was downloaded from `https://cdn.posit.co/r/ubuntu-2404/pkgs/r-4.6.1_1_amd64.deb` and extracted under `/tmp`. Its `R` binary runs only when `R_HOME` and `LD_LIBRARY_PATH` point at the extracted tree, because the package is built for `/opt/R/4.6.1`. Passwordless sudo is not available, and a user-namespace bind mount did not stay in place long enough to finish `renv::restore()` on R 4.6.1. A restore started on the system R 4.3.3 was stopped because that is not the locked version. `/tmp` on that WSL session no longer contains the extracted tree.

## Clean restore

Not completed on R 4.6.1. The Windows library was created by `renv::install()` and `renv::snapshot()`, not by a clean `renv::restore()`. The GitHub Actions `renv::restore()` on ubuntu-latest with R 4.6.1 failed on `libglpk.so.40` before tests or either report.

## Original example

`Rscript run-tests.R` in this review included the pediatric tests and passed. The pediatric report at `output/report.html` was produced earlier by `Rscript -e "targets::tar_make()"` on Windows R 4.6.1. This review did not run that pipeline again, so the restored metadata file would not match a newly written targets store. `make data`, `make test`, and `make report` were not executed with GNU Make on Linux.

## Numerical and visual checks

The integrity script and the passing testthat file cover repeated rows, COVID reconciliation, leading zeros, join multiplication, missing and zero denominators, absent occupations, hand-calculated ratios, and tied ranks. The rebuilt ratio figure states the 15–64 / without-Åland versus 18–74 / whole-country difference in the image itself. The HTML summary states the same saved-audit arithmetic, definitions, and population limit. Long rank labels remain abbreviated; the table has the full names.

## Remaining limitations and unverified checks

- GitHub Actions has not passed. The `libglpk-dev` change is local until the workflow is run again.
- `renv::restore()` on Linux R 4.6.1 was not completed, and GNU Make was not used to build either report.
- The ratio remains a five-year descriptive comparison against a rounded employment stock with a different age range and with Åland in the denominator only.
- Disclosure control can change the released ranking. No sampling interval was estimated.
