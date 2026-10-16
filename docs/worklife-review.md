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

Linux check, 16 October 2026, WSL Ubuntu 24.04, GNU Make 4.3, Quarto already installed. The distro's system R is 4.3.3, so it was not used. Passwordless sudo is not available, and `/opt` is not writable. R 4.6.1 (2026-06-24) was taken from `https://cdn.posit.co/r/ubuntu-2404/pkgs/r-4.6.1_1_amd64.deb` and extracted under the home directory. The development libraries that `apt` would install (`libcurl4-openssl-dev`, `libssl-dev`, `zlib1g-dev`, `libglpk-dev`, `libglpk40`, `libuv1-dev`, `libcolamd3`, `libamd3`, `libsuitesparseconfig7`) were downloaded with `apt-get download`, extracted into that same home directory, and exposed with `PKG_CONFIG_PATH`, `LIBRARY_PATH`, and `LD_LIBRARY_PATH`. `libxml2-dev` returned 404 from the stale package index. Pandoc came from the existing Quarto installation.

A clean copy of the working tree, including the gitignored snapshot zip and the saved audit, was placed in that home directory. `.git`, `renv/library`, both targets stores, and `output/` were left out. In that copy:

```text
Rscript -e 'renv::consent(provided=TRUE); renv::restore(prompt=FALSE)'
make test
make data
make report
make worklife
```

`renv::status()` then reported no issues and `synchronized = TRUE`. `make test` exited 0. `make data` wrote the synthetic parquet file. `make report` rendered the pediatric report. `make worklife` rendered the worklife report from the local snapshot. The zip digest stayed `ad2261e1bcc95b68d852e96e7718b740ee5bbcb3a15c70d6e6d5fd80ece5713f`. `data/worklife/provenance.yml` and `data/worklife/audit/audit.yml` were unchanged, so the rebuild did not refresh remote data. This run is not a GitHub Actions run.

## Clean restore

Completed on the prepared WSL R 4.6.1 library described above. `renv::restore()` installed the 80 locked packages, including `arrow` 25.0.1 built from the package's bundled C++ sources in about 8 minutes, `igraph` 2.3.4 linked with `-lglpk`, `curl` 8.0.0, `fs` 2.1.0, and `targets` 1.12.0. Loading `testthat`, `targets`, `ggplot2`, `arrow`, and `igraph` succeeded. Earlier attempts in the same session failed while those shared libraries were incomplete: `curl` could not find `libcurl`, `fs` linked a non-PIC `libuv.a`, and `igraph` loaded only after `libcolamd.so.3`, `libamd.so.3`, and `libsuitesparseconfig.so.7` were present. `libglpk40` itself depends on `libamd3` and `libcolamd3`; `apt install libglpk-dev` pulls that chain, including SuiteSparse config. The Windows library was still created earlier by `renv::install()` and `renv::snapshot()`, not by this Linux restore.

The earlier GitHub Actions `renv::restore()` on ubuntu-latest with R 4.6.1 failed while loading `igraph` because `libglpk.so.40` was missing. The workflow now installs `libglpk-dev` before restore. Actions was not run again after that change.

## Original example

On the Linux copy, `make test` included the pediatric tests and passed, `make data` regenerated the synthetic visits file, and `make report` wrote `output/report.html` (45,830 bytes). The pediatric commands in the Makefile are unchanged. The Windows `output/report.html` from the earlier pediatric pipeline was not replaced by this Linux run. The working tree still has `_targets/meta/meta` restored to the pre-feature version from `a0876a9`; that file is not what the Linux copy used, because the copy excluded `_targets`.

## Numerical and visual checks

The integrity script and the passing testthat file cover repeated rows, COVID reconciliation, leading zeros, join multiplication, missing and zero denominators, absent occupations, hand-calculated ratios, and tied ranks. The Linux-built HTML contains the ratio wording, the 15–64 and 18–74 limits, Åland, and the displayed ratio 13,4. The Windows report rebuilt earlier in this review states the same saved-audit arithmetic, definitions, and population limit in the summary, methods, figure captions, and interpretation. Long rank labels remain abbreviated; the table has the full names.

## Remaining limitations and unverified checks

- GitHub Actions has not been run again. The `libglpk-dev` change is local until that workflow runs. The WSL restore is not that run.
- The WSL machine cannot `apt install` without a password, so the successful restore used extracted library packages and an extracted R 4.6.1 rather than the system paths under `/usr` and `/opt`.
- The ratio remains a five-year descriptive comparison against a rounded employment stock with a different age range and with Åland in the denominator only.
- Disclosure control can change the released ranking. No sampling interval was estimated.
