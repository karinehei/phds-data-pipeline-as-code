# Separate targets pipeline for the occupational-disease analysis.
# The pediatric pipeline in _targets.R does not call this script.
#
#   Rscript scripts/build_worklife.R

library(targets)
tar_source("R/")

tar_option_set(
  packages = c("yaml", "ggplot2", "digest", "readxl", "jsonlite", "quarto", "curl")
)

list(
  tar_target(
    pin,
    worklife_read_pin("data_contract/worklife_source.yml")
  ),
  tar_target(
    snapshot_zip,
    {
      paths <- worklife_paths(".")
      assessment <- assess_worklife_file(
        paths$snapshot_zip, pin$expected_bytes, pin$sha256
      )
      if (!isTRUE(assessment$ok)) {
        stop(assessment$reason)
      }
      assert_worklife_archive_members(
        paths$snapshot_zip,
        unlist(pin$archive_members, use.names = FALSE)
      )
      if (!file.exists(paths$provenance)) {
        stop("Provenance file is missing. Run scripts/acquire_worklife.R.")
      }
      paths$snapshot_zip
    },
    format = "file"
  ),
  tar_target(
    codebook_csv,
    "data_contract/worklife_codebook.csv",
    format = "file"
  ),
  tar_target(
    codebook,
    assert_codebook_matches_zip(snapshot_zip, codebook_csv, pin$codebook_member)
  ),
  tar_target(
    cases,
    {
      loaded <- read_worklife_cases(snapshot_zip, pin$case_member)
      assert_pinned_snapshot(loaded, pin)
      loaded
    }
  ),
  tar_target(
    denominator,
    read_worklife_denominator(snapshot_zip, pin$denominator_member)
  ),
  tar_target(
    metrics,
    occupation_metrics(cases, denominator, codebook, pin$covid_label)
  ),
  tar_target(
    exposure,
    exposure_composition(cases, metrics, codebook, pin$covid_label)
  ),
  tar_target(
    provenance_yml,
    "data/worklife/provenance.yml",
    format = "file"
  ),
  tar_target(
    audit_yml,
    "data/worklife/audit/audit.yml",
    format = "file"
  ),
  tar_target(
    audit_csv,
    "data/worklife/audit/comparison.csv",
    format = "file"
  ),
  tar_target(
    plots,
    make_worklife_plots(metrics, exposure)
  ),
  tar_target(
    report_inputs,
    c(
      "report_worklife.qmd",
      "report_worklife.css",
      list.files("R", pattern = "^worklife_.*\\.R$", full.names = TRUE)
    ),
    format = "file"
  ),
  tar_target(
    report,
    {
      report_inputs
      render_worklife_report(
        metrics, exposure, plots, provenance_yml, audit_yml, audit_csv
      )
    },
    format = "file"
  )
)
