#' Generate synthetic pediatric visit data
#'
#' Creates a tidy visits-level table conforming to the pediatric_visits data
#' contract. Deterministic given \code{seed}. Uses realistic-ish distributions
#' for age (skewed younger), visit counts per patient (few frequent visitors),
#' diagnosis codes (ICD-10 dictionary), and multiple sites.
#'
#' @param n_patients Integer. Number of unique patients.
#' @param n_visits Integer. Target total number of visits (actual count may vary
#'   slightly due to sampling).
#' @param seed Integer. Random seed for reproducibility.
#' @param out_path_parquet Character. Path to write Parquet file. If \code{NULL},
#'   data is returned without writing.
#'
#' @return A data frame (tibble) with columns: patient_id, age_years, sex,
#'   visit_date, diagnosis_code, site_id, weight_kg.
#'
#' @export
#'
#' @examples
#' df <- generate_synthetic_data(100, 500, seed = 42, out_path_parquet = NULL)
#' generate_synthetic_data(50, 200, seed = 123, out_path_parquet = "visits.parquet")
generate_synthetic_data <- function(n_patients,
                                    n_visits,
                                    seed,
                                    out_path_parquet = NULL) {
  stopifnot(
    n_patients > 0,
    n_visits >= n_patients,
    is.numeric(seed),
    length(seed) == 1
  )

  set.seed(as.integer(seed))

  # ICD-10 diagnosis codes (common pediatric)
  diagnosis_codes <- c(
    "J06.9", "J00", "H66.9", "K21.0", "R50.9",
    "J18.9", "A09", "R10.4", "L08.9", "Z00.121",
    "Z23", "R51", "J02.9", "R05", "N39.0"
  )

  site_ids <- c("SITE_A", "SITE_B", "SITE_C", "SITE_D")
  sex_levels <- c("M", "F", "Other", "Unknown")

  # Patient-level attributes (one row per patient)
  patient_id <- sprintf("P%05d", seq_len(n_patients))

  # Age: skewed younger (beta-like via sample weights)
  age_probs <- (19:1)^1.5
  age_probs <- age_probs / sum(age_probs)
  age_years <- sample(0:18, size = n_patients, replace = TRUE, prob = age_probs)

  sex <- sample(sex_levels, size = n_patients, replace = TRUE, prob = c(0.48, 0.48, 0.02, 0.02))

  # Visit counts per patient: negative binomial (few patients, many visits)
  target_per_patient <- n_visits / n_patients
  visits_per_patient <- stats::rnbinom(
    n_patients,
    size = 2,
    mu = max(1, target_per_patient)
  )
  visits_per_patient <- pmax(1L, visits_per_patient)
  total_visits <- sum(visits_per_patient)

  # Expand to visit-level
  patient_idx <- rep(seq_len(n_patients), times = visits_per_patient)
  n <- length(patient_idx)

  visit_date <- as.Date("2023-01-01") + sample(0:730, size = n, replace = TRUE)
  diagnosis_code <- sample(diagnosis_codes, size = n, replace = TRUE)
  site_id <- sample(site_ids, size = n, replace = TRUE, prob = c(0.4, 0.3, 0.2, 0.1))

  # Weight: ~85% present, within pediatric bounds; some missing (soft rule)
  weight_kg <- ifelse(
    stats::runif(n) < 0.85,
    round(stats::runif(n, 5, 80) + stats::rnorm(n, 0, 2), 1),
    NA_real_
  )
  weight_kg <- pmax(2, pmin(200, weight_kg))

  out <- data.frame(
    patient_id = patient_id[patient_idx],
    age_years = as.integer(age_years[patient_idx]),
    sex = sex[patient_idx],
    visit_date = visit_date,
    diagnosis_code = diagnosis_code,
    site_id = site_id,
    weight_kg = weight_kg,
    stringsAsFactors = FALSE
  )

  if (!is.null(out_path_parquet)) {
    dir.create(dirname(out_path_parquet), recursive = TRUE, showWarnings = FALSE)
    arrow::write_parquet(out, out_path_parquet)
  }

  out
}

#' Generate demo data and write to standard location
#'
#' CLI-friendly wrapper that writes synthetic pediatric visits to
#' \code{data/synthetic/visits.parquet}. Uses fixed defaults for quick demos.
#'
#' @param n_patients Integer. Number of patients (default 200).
#' @param n_visits Integer. Approximate total visits (default 800).
#' @param seed Integer. Random seed (default 42).
#' @param out_dir Character. Output directory (default \code{data/synthetic}).
#'
#' @return Invisibly, the path to the written Parquet file.
#'
#' @export
#'
#' @examples
#' generate_demo_data()
#' generate_demo_data(n_patients = 50, n_visits = 200)
generate_demo_data <- function(n_patients = 200,
                               n_visits = 800,
                               seed = 42,
                               out_dir = "data/synthetic") {
  out_path <- file.path(out_dir, "visits.parquet")
  generate_synthetic_data(
    n_patients = n_patients,
    n_visits = n_visits,
    seed = seed,
    out_path_parquet = out_path
  )
  message("Wrote ", out_path)
  invisible(out_path)
}
