# targets pipeline: phds-data-pipeline-as-code
#
# Run the pipeline:
#   tar_make()
#
# Run with a fresh start (rebuild all):
#   tar_destroy()
#   tar_make()
#
# Inspect pipeline:
#   tar_manifest()
#   tar_visnetwork()

library(targets)
tar_source("R/")

tar_option_set(
  packages = c("yaml", "arrow", "quarto", "ggplot2")
)

list(
  # 1) Contract schema
  tar_target(
    contract,
    read_contract("data_contract/contract.yaml")
  ),

  # 2) Synthetic data
  tar_target(
    synthetic_data,
    {
      generate_synthetic_data(
        n_patients = 200,
        n_visits = 800,
        seed = 123,
        out_path_parquet = "data/synthetic/visits.parquet"
      )
      "data/synthetic/visits.parquet"
    },
    format = "file"
  ),

  # 3) Load parquet
  tar_target(
    df,
    arrow::read_parquet(synthetic_data)
  ),

  # 4) Validation (stop on errors)
  tar_target(
    validation,
    {
      res <- validate_against_contract(df, contract)
      if (!res$valid) {
        stop("Contract validation failed: ", paste(res$errors, collapse = "; "))
      }
      res
    }
  ),

  # 5) Metrics
  tar_target(
    metrics,
    compute_metrics(df)
  ),

  # 6) Plots
  tar_target(
    plots,
    make_plots(df)
  ),

  # 7) Ensure output/ exists, save artifacts, render report
  tar_target(
    render_report,
    {
      dir.create("output", showWarnings = FALSE, recursive = TRUE)
      dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
      saveRDS(metrics, "output/metrics.rds")
      saveRDS(validation, "output/validation.rds")
      for (nm in names(plots)) {
        p <- plots[[nm]]
        if (!is.null(p) && inherits(p, "ggplot")) {
          ggplot2::ggsave(
            file.path("output", "figures", paste0(nm, ".png")),
            p, width = 6, height = 4
          )
        }
      }
      quarto::quarto_render("report.qmd")
      file.copy("report.html", "output/report.html", overwrite = TRUE)
      if (dir.exists("report_files")) {
        file.copy("report_files", "output", recursive = TRUE, overwrite = TRUE)
        unlink("report_files", recursive = TRUE)
      }
      unlink("report.html")
      "output/report.html"
    },
    format = "file"
  )
)
