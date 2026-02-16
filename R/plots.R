#' Create plots for the pipeline report
#'
#' Returns ggplot objects for use in report.qmd.
#'
#' @param df Data frame. Validated pediatric visits.
#' @return List of ggplot objects: age_hist, top_diagnoses_bar, visits_per_week.
#' @export
make_plots <- function(df) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(list(
      age_hist = NULL,
      top_diagnoses_bar = NULL,
      visits_per_week = NULL,
      message = "Install ggplot2 for plots"
    ))
  }
  if (nrow(df) == 0) {
    return(list(age_hist = NULL, top_diagnoses_bar = NULL, visits_per_week = NULL))
  }

  # Histogram of age_years
  age_hist <- ggplot2::ggplot(df, ggplot2::aes(x = age_years)) +
    ggplot2::geom_histogram(binwidth = 1, fill = "steelblue", color = "white") +
    ggplot2::labs(title = "Age distribution", x = "Age (years)", y = "Count") +
    ggplot2::theme_minimal()

  # Bar chart of top diagnoses
  dx_tab <- sort(table(df$diagnosis_code), decreasing = TRUE)
  k <- min(10, length(dx_tab))
  dx_df <- data.frame(
    diagnosis_code = factor(names(dx_tab)[seq_len(k)], levels = rev(names(dx_tab)[seq_len(k)])),
    n = as.vector(dx_tab)[seq_len(k)]
  )
  top_diagnoses_bar <- ggplot2::ggplot(dx_df, ggplot2::aes(x = diagnosis_code, y = n, fill = diagnosis_code)) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Top diagnosis codes", x = "Diagnosis code", y = "Count") +
    ggplot2::theme_minimal()

  # Time series of visits per week
  df$week <- as.Date(cut(as.Date(df$visit_date), "week"))
  visits_weekly <- as.data.frame(table(df$week, dnn = "week"))
  visits_weekly$week <- as.Date(visits_weekly$week)
  visits_weekly$n <- visits_weekly$Freq
  visits_weekly$Freq <- NULL

  visits_per_week <- ggplot2::ggplot(visits_weekly, ggplot2::aes(x = week, y = n)) +
    ggplot2::geom_line(color = "steelblue", linewidth = 1) +
    ggplot2::geom_point(color = "steelblue", size = 2) +
    ggplot2::labs(title = "Visits per week", x = "Week", y = "Visits") +
    ggplot2::theme_minimal() +
    ggplot2::scale_x_date(date_breaks = "1 month", date_labels = "%Y-%m")

  list(
    age_hist = age_hist,
    top_diagnoses_bar = top_diagnoses_bar,
    visits_per_week = visits_per_week
  )
}
