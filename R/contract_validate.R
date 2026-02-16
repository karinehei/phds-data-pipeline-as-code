#' Read data contract from YAML file
#'
#' @param path Character. Path to contract YAML file.
#' @return Parsed contract as a nested list.
#' @export
read_contract <- function(path = "data_contract/contract.yaml") {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required. Install with install.packages('yaml')")
  }
  contract <- yaml::read_yaml(path)
  if (is.null(contract$datasets)) {
    stop("Contract must contain 'datasets' key")
  }
  contract
}

#' Get column schema for a dataset from contract
#'
#' @param contract List. Parsed contract from \code{read_contract()}.
#' @param dataset_name Character. Name of dataset (e.g. \code{"pediatric_visits"}).
#' @return List of column specs.
#' @keywords internal
get_dataset_schema <- function(contract, dataset_name = NULL) {
  datasets <- contract$datasets
  if (is.null(dataset_name)) {
    dataset_name <- names(datasets)[[1L]]
  }
  if (!dataset_name %in% names(datasets)) {
    stop("Dataset '", dataset_name, "' not found in contract")
  }
  datasets[[dataset_name]]
}

#' Check if required columns exist
#'
#' @param df Data frame.
#' @param required_names Character vector of required column names.
#' @return List with \code{ok} (logical) and \code{errors} (character).
#' @keywords internal
check_required_columns <- function(df, required_names) {
  missing <- setdiff(required_names, names(df))
  ok <- length(missing) == 0L
  errors <- if (!ok) {
    paste0("Missing required column(s): ", paste(missing, collapse = ", "))
  } else {
    character(0)
  }
  list(ok = ok, errors = errors)
}

#' Check column has no NA for non-nullable fields
#'
#' @param df Data frame.
#' @param col_name Character. Column name.
#' @return List with \code{ok} (logical) and \code{errors} (character).
#' @keywords internal
check_non_null <- function(df, col_name) {
  if (!col_name %in% names(df)) return(list(ok = TRUE, errors = character(0)))
  n_na <- sum(is.na(df[[col_name]]))
  ok <- n_na == 0L
  errors <- if (!ok) {
    paste0(col_name, ": ", n_na, " NA value(s) (non-nullable)")
  } else {
    character(0)
  }
  list(ok = ok, errors = errors)
}

#' Check column type matches contract
#'
#' @param df Data frame.
#' @param col_name Character. Column name.
#' @param type_spec Character. Contract type: \code{string}, \code{integer}, \code{numeric}, \code{date}.
#' @return List with \code{ok} (logical) and \code{errors} (character).
#' @keywords internal
check_column_type <- function(df, col_name, type_spec) {
  if (!col_name %in% names(df)) return(list(ok = TRUE, errors = character(0)))
  x <- df[[col_name]]
  type_spec <- tolower(type_spec)
  ok <- switch(type_spec,
    string = is.character(x),
    integer = is.integer(x) || (is.numeric(x) && all(x[!is.na(x)] == as.integer(x[!is.na(x)]))),
    numeric = is.numeric(x),
    date = inherits(x, "Date"),
    FALSE
  )
  if (is.null(ok)) ok <- FALSE
  errors <- if (!ok) {
    paste0(col_name, ": expected type '", type_spec, "', got '", class(x)[[1L]], "'")
  } else {
    character(0)
  }
  list(ok = ok, errors = errors)
}

#' Check numeric/integer column is within range
#'
#' @param df Data frame.
#' @param col_name Character. Column name.
#' @param min_val Numeric or \code{NULL}.
#' @param max_val Numeric or \code{NULL}.
#' @return List with \code{ok} (logical) and \code{errors} (character).
#' @keywords internal
check_range <- function(df, col_name, min_val = NULL, max_val = NULL) {
  if (!col_name %in% names(df)) return(list(ok = TRUE, errors = character(0)))
  x <- df[[col_name]]
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(list(ok = TRUE, errors = character(0)))
  out_of_range <- logical(length(x))
  if (!is.null(min_val)) out_of_range <- out_of_range | (x < min_val)
  if (!is.null(max_val)) out_of_range <- out_of_range | (x > max_val)
  n_bad <- sum(out_of_range)
  ok <- n_bad == 0L
  errors <- if (!ok) {
    paste0(col_name, ": ", n_bad, " value(s) outside range [", min_val, ", ", max_val, "]")
  } else {
    character(0)
  }
  list(ok = ok, errors = errors)
}

#' Check character column values are in allowed set
#'
#' @param df Data frame.
#' @param col_name Character. Column name.
#' @param allowed Character vector of allowed values.
#' @return List with \code{ok} (logical) and \code{errors} (character).
#' @keywords internal
check_enum <- function(df, col_name, allowed) {
  if (!col_name %in% names(df) || length(allowed) == 0L) {
    return(list(ok = TRUE, errors = character(0)))
  }
  x <- df[[col_name]]
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(list(ok = TRUE, errors = character(0)))
  invalid <- !x %in% allowed
  n_bad <- sum(invalid)
  ok <- n_bad == 0L
  errors <- if (!ok) {
    bad_vals <- unique(x[invalid])
    paste0(col_name, ": ", n_bad, " invalid value(s), e.g. ", paste(head(bad_vals, 3), collapse = ", "))
  } else {
    character(0)
  }
  list(ok = ok, errors = errors)
}

#' Check missing rate for optional column (warning)
#'
#' @param df Data frame.
#' @param col_name Character. Column name.
#' @param threshold Numeric. Max allowed missing rate (0-1). If exceeded, add warning.
#' @return List with \code{ok} (logical) and \code{warnings} (character).
#' @keywords internal
check_missing_rate <- function(df, col_name, threshold = 0.2) {
  if (!col_name %in% names(df)) return(list(ok = TRUE, warnings = character(0)))
  n <- nrow(df)
  n_na <- sum(is.na(df[[col_name]]))
  rate <- n_na / n
  ok <- rate <= threshold
  warnings <- if (!ok && n > 0L) {
    paste0(col_name, ": missing rate ", round(rate * 100, 1), "% exceeds threshold ", threshold * 100, "%")
  } else {
    character(0)
  }
  list(ok = ok, warnings = warnings)
}

#' Validate data frame against contract
#'
#' Runs hard checks (errors) and soft checks (warnings). Errors fail the
#' pipeline; warnings do not.
#'
#' @param df Data frame to validate.
#' @param contract List. Parsed contract from \code{read_contract()}, or path to YAML.
#' @param dataset_name Character. Dataset name in contract (default: first dataset).
#' @param weight_missing_threshold Numeric. Max allowed missing rate for weight_kg (0-1).
#' @return List with \code{valid} (logical), \code{errors} (character), \code{warnings} (character).
#'
#' @export
#'
#' @examples
#' contract <- read_contract("data_contract/contract.yaml")
#' df <- data.frame(patient_id = "P1", age_years = 5L, sex = "M", visit_date = Sys.Date(),
#'   diagnosis_code = "J06.9", site_id = "SITE_A", weight_kg = 20)
#' validate_against_contract(df, contract)
validate_against_contract <- function(df,
                                     contract,
                                     dataset_name = NULL,
                                     weight_missing_threshold = 0.2) {
  if (is.character(contract)) {
    contract <- read_contract(contract)
  }
  if (!is.data.frame(df)) {
    return(list(valid = FALSE, errors = "Input must be a data frame", warnings = character(0)))
  }

  schema <- get_dataset_schema(contract, dataset_name)
  cols <- schema$columns
  if (is.null(cols) || length(cols) == 0L) {
    return(list(valid = FALSE, errors = "No columns defined in contract", warnings = character(0)))
  }

  errors <- character(0)
  warnings <- character(0)

  # Required columns
  required_names <- vapply(cols, function(c) {
    if (isTRUE(c$required)) c$name else NA_character_
  }, character(1))
  required_names <- required_names[!is.na(required_names)]
  rc <- check_required_columns(df, required_names)
  if (!rc$ok) errors <- c(errors, rc$errors)

  # Per-column checks (only for columns that exist)
  for (col_spec in cols) {
    name <- col_spec$name
    if (!name %in% names(df)) next

    # Type
    if (!is.null(col_spec$type)) {
      tc <- check_column_type(df, name, col_spec$type)
      if (!tc$ok) errors <- c(errors, tc$errors)
    }

    # Non-null (required or nullable: false)
    if (isTRUE(!col_spec$nullable) || isTRUE(col_spec$required)) {
      nn <- check_non_null(df, name)
      if (!nn$ok) errors <- c(errors, nn$errors)
    }

    # Range (min/max)
    if (!is.null(col_spec$min) || !is.null(col_spec$max)) {
      rc <- check_range(df, name, col_spec$min, col_spec$max)
      if (!rc$ok) errors <- c(errors, rc$errors)
    }

    # Enum (allowed_values)
    if (!is.null(col_spec$allowed_values)) {
      ec <- check_enum(df, name, col_spec$allowed_values)
      if (!ec$ok) errors <- c(errors, ec$errors)
    }

    # Soft: weight_kg missing rate
    if (name == "weight_kg" && !isTRUE(col_spec$required)) {
      mr <- check_missing_rate(df, name, threshold = weight_missing_threshold)
      if (!mr$ok) warnings <- c(warnings, mr$warnings)
    }
  }

  valid <- length(errors) == 0L
  list(valid = valid, errors = errors, warnings = warnings)
}

#' Validate data and optionally stop on error (pipeline-friendly)
#'
#' Wrapper around \code{validate_against_contract()}. Stops with error message
#' if validation fails; useful in targets pipelines.
#'
#' @param data Data frame to validate.
#' @param contract_path Character. Path to contract YAML.
#' @param stop_on_error Logical. If \code{TRUE}, stop on validation failure.
#' @return Invisibly, the validation result list.
#' @export
validate_contract <- function(data,
                             contract_path = "data_contract/contract.yaml",
                             stop_on_error = TRUE) {
  res <- validate_against_contract(data, read_contract(contract_path))
  if (stop_on_error && !res$valid) {
    stop("Contract validation failed: ", paste(res$errors, collapse = "; "))
  }
  invisible(res)
}

#' Print human-readable validation summary
#'
#' @param x List. Result from \code{validate_against_contract()}.
#' @param ... Passed to \code{cat()}.
#' @return Invisibly \code{x}.
#' @export
print_validation_summary <- function(x, ...) {
  stopifnot(is.list(x), "valid" %in% names(x), "errors" %in% names(x), "warnings" %in% names(x))
  status <- if (x$valid) "PASS" else "FAIL"
  cat("Validation: ", status, "\n", sep = "", ...)
  if (length(x$errors) > 0L) {
    cat("Errors:\n", sep = "", ...)
    for (e in x$errors) cat("  - ", e, "\n", sep = "", ...)
  }
  if (length(x$warnings) > 0L) {
    cat("Warnings:\n", sep = "", ...)
    for (w in x$warnings) cat("  - ", w, "\n", sep = "", ...)
  }
  if (length(x$errors) == 0L && length(x$warnings) == 0L && x$valid) {
    cat("No issues.\n", ...)
  }
  invisible(x)
}
