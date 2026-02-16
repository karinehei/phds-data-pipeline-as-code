#' Compute summary metrics from validated visit data
#'
#' Returns a list of tibbles/data.frames for use in report.qmd.
#'
#' @param df Data frame. Validated pediatric visits (contract-compliant).
#' @return List of tibbles: counts_by_site, age_summary, top_diagnoses,
#'   missingness_rates.
#' @export
compute_metrics <- function(df) {
  n <- nrow(df)

  # Counts by site_id
  counts_by_site <- as.data.frame(table(df$site_id))
  names(counts_by_site) <- c("site_id", "n")

  # Age distribution summary
  age_summary <- data.frame(
    stat = c("min", "q25", "median", "mean", "q75", "max"),
    value = c(
      min(df$age_years, na.rm = TRUE),
      quantile(df$age_years, 0.25, na.rm = TRUE),
      median(df$age_years, na.rm = TRUE),
      mean(df$age_years, na.rm = TRUE),
      quantile(df$age_years, 0.75, na.rm = TRUE),
      max(df$age_years, na.rm = TRUE)
    )
  )

  # Top diagnosis_code frequencies
  dx_tab <- sort(table(df$diagnosis_code), decreasing = TRUE)
  top_diagnoses <- data.frame(
    diagnosis_code = names(dx_tab),
    n = as.vector(dx_tab),
    pct = round(100 * as.vector(dx_tab) / n, 1)
  )
  top_diagnoses <- head(top_diagnoses, 10)

  # Missingness rates
  cols_to_check <- c(
    "patient_id", "age_years", "sex", "visit_date",
    "diagnosis_code", "site_id", "weight_kg"
  )
  cols_present <- intersect(cols_to_check, names(df))
  n_missing <- vapply(cols_present, function(c) sum(is.na(df[[c]])), integer(1))
  missingness_rates <- data.frame(
    column = cols_present,
    n_missing = n_missing,
    n_total = n,
    pct_missing = round(100 * n_missing / n, 1)
  )

  list(
    counts_by_site = counts_by_site,
    age_summary = age_summary,
    top_diagnoses = top_diagnoses,
    missingness_rates = missingness_rates
  )
}
