#' Columns shown in the main report table.
#'
#' @param table Metrics table.
#' @return Display data frame with Finnish names.
#' @export
worklife_main_table <- function(table) {
  show <- table[table$in_case_extract %in% TRUE, , drop = FALSE]
  out <- data.frame(
    Koodi = show$occupation,
    Ammattiluokka = show$label_fi,
    Tapaukset = show$n_cases,
    COVID = show$n_covid,
    Muut = show$n_other,
    Työlliset = show$employment,
    "Suhdeluku / 1 000" = round(show$period_cases_per_1000, 1),
    "Suhdeluku ilman COVID-19" = round(show$period_other_per_1000, 1),
    "Viitteellinen vuositaso / 1 000" = round(show$annualised_cases_per_1000, 2),
    "Sija, lukumäärä" = show$rank_count,
    "Sija, suhdeluku" = show$rank_ratio,
    "Sija, lukumäärä ilman COVID-19" = show$rank_count_other,
    "Sija, suhdeluku ilman COVID-19" = show$rank_ratio_other,
    "Karkea nimittäjä" = ifelse(show$coarse_denominator, "kyllä", ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out
}

#' Occupations that are not in the released case extract.
#'
#' @param table Metrics table.
#' @return Display data frame.
#' @export
worklife_absent_table <- function(table) {
  show <- table[!(table$in_case_extract %in% TRUE), , drop = FALSE]
  data.frame(
    Koodi = show$occupation,
    Ammattiluokka = show$label_fi,
    Työlliset = show$employment,
    Nimittäjän_tila = show$denominator_status,
    Huomio = "Ei julkaistussa tapausotteessa. Puuttumista ei tulkita nollaksi.",
    stringsAsFactors = FALSE
  )
}

#' Write figures and render the self-contained worklife report.
#'
#' @param metrics Metrics list.
#' @param exposure Exposure data frame.
#' @param plots Named ggplot list.
#' @param provenance_path Provenance yml.
#' @param audit_yml Audit yml.
#' @param audit_csv Comparison csv.
#' @param qmd Quarto source.
#' @return Path to the HTML report.
#' @export
render_worklife_report <- function(metrics,
                                   exposure,
                                   plots,
                                   provenance_path,
                                   audit_yml,
                                   audit_csv,
                                   qmd = "report_worklife.qmd") {
  if (!requireNamespace("quarto", quietly = TRUE)) stop("Package 'quarto' is required")
  for (path in c(provenance_path, audit_yml, audit_csv, qmd)) {
    if (!file.exists(path)) stop("Report input is missing: ", path)
  }
  out_dir <- "output/worklife"
  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(metrics, file.path(out_dir, "results.rds"))
  saveRDS(exposure, file.path(out_dir, "exposure.rds"))
  sizes <- list(
    counts = c(width = 10, height = 8.2),
    ratios = c(width = 10, height = 8.2),
    ranks = c(width = 11, height = 13),
    exposure = c(width = 11, height = 8)
  )
  for (nm in names(plots)) {
    plot <- plots[[nm]]
    if (is.null(plot) || !inherits(plot, "ggplot")) {
      stop("Figure is not a ggplot: ", nm)
    }
    size <- sizes[[nm]]
    if (is.null(size)) size <- c(width = 9, height = 7)
    ggplot2::ggsave(
      file.path(fig_dir, paste0(nm, ".png")),
      plot,
      width = unname(size[["width"]]),
      height = unname(size[["height"]]),
      dpi = 150,
      bg = "white"
    )
  }
  quarto::quarto_render(qmd, execute_debug = FALSE)
  html <- sub("\\.qmd$", ".html", qmd)
  if (!file.exists(html)) stop("Quarto did not write ", html)
  dest <- file.path(out_dir, "report.html")
  if (!file.copy(html, dest, overwrite = TRUE)) stop("Could not copy the report")
  unlink(html)
  sidecar <- sub("\\.html$", "_files", html)
  if (dir.exists(sidecar)) unlink(sidecar, recursive = TRUE)
  dest
}
