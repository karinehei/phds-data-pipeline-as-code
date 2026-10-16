#' Round halves away from zero to the nearest thousand.
#'
#' @param x Numeric vector.
#' @return Numeric vector.
#' @export
round_to_thousand <- function(x) {
  ifelse(is.na(x), NA_real_, sign(x) * floor(abs(x) / 1000 + 0.5) * 1000)
}

#' GET or POST JSON and return the response text.
#'
#' @param url URL.
#' @param body List to POST, or \code{NULL} for GET.
#' @return List with \code{status} and \code{text}.
#' @export
worklife_fetch_json <- function(url, body = NULL) {
  if (!requireNamespace("curl", quietly = TRUE)) stop("Package 'curl' is required")
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required")
  handle <- curl::new_handle()
  if (!is.null(body)) {
    payload <- jsonlite::toJSON(body, auto_unbox = FALSE)
    curl::handle_setheaders(handle, "Content-Type" = "application/json")
    curl::handle_setopt(handle, postfields = payload)
  }
  raw <- curl::curl_fetch_memory(url, handle = handle)
  text <- rawToChar(raw$content)
  Encoding(text) <- "UTF-8"
  if (raw$status_code < 200 || raw$status_code >= 300) {
    stop("HTTP ", raw$status_code, " from ", url, ": ", substr(text, 1, 500))
  }
  list(status = raw$status_code, text = text)
}

#' Find one metadata variable whose label matches a pattern.
#'
#' @param meta PxWeb metadata list.
#' @param pattern Regex.
#' @return The variable list.
#' @export
worklife_meta_variable <- function(meta, pattern) {
  hits <- Filter(function(v) grepl(pattern, v$text, ignore.case = TRUE), meta$variables)
  if (length(hits) != 1L) {
    stop("Expected one StatFin variable matching ", pattern, "; found ", length(hits))
  }
  hits[[1L]]
}

#' Value code whose label matches a pattern.
#'
#' @param variable PxWeb variable.
#' @param pattern Regex.
#' @return Character code.
#' @export
worklife_value_code <- function(variable, pattern) {
  texts <- unlist(variable$valueTexts)
  values <- unlist(variable$values)
  hit <- grep(pattern, texts, ignore.case = TRUE)
  if (length(hit) != 1L) {
    stop("Expected one value matching ", pattern, " in ", variable$text)
  }
  values[[hit]]
}

#' Build a PxWeb query for occupation, area, year and sex.
#'
#' @param codes Named list of variable codes and selected value codes.
#' @return Query list.
#' @export
worklife_px_query <- function(codes) {
  list(
    query = lapply(names(codes), function(code) {
      list(
        code = jsonlite::unbox(code),
        selection = list(
          filter = jsonlite::unbox("item"),
          values = as.character(codes[[code]])
        )
      )
    }),
    response = list(format = jsonlite::unbox("json"))
  )
}

#' Parse a PxWeb JSON data response into a data frame of keys and values.
#'
#' @param text Response JSON.
#' @return Data frame with \code{key} columns \code{k1}... and \code{value}.
#' @export
parse_px_data <- function(text) {
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  if (length(parsed$data) == 0L) stop("PxWeb response contained no data rows.")
  key_n <- length(parsed$data[[1L]]$key)
  col_names <- c(paste0("k", seq_len(key_n)), "value")
  rows <- lapply(parsed$data, function(item) {
    keys <- as.character(unlist(item$key))
    if (length(keys) != key_n) {
      stop("PxWeb data row has ", length(keys), " keys; expected ", key_n, ".")
    }
    value <- suppressWarnings(as.numeric(unlist(item$values)[[1L]]))
    stats::setNames(c(keys, value), col_names)
  })
  out <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  out$value <- as.numeric(out$value)
  rownames(out) <- NULL
  out
}

#' Compare packaged denominators with rounded mean StatFin employment.
#'
#' Does not replace the packaged values.
#'
#' @param denominator Denominator data frame.
#' @param statfin Data frame with \code{occupation}, \code{year}, \code{employment}.
#' @param statfin_codes Occupation codes that exist in the StatFin metadata.
#' @param years Years that should be present.
#' @return Comparison data frame.
#' @export
compare_packaged_denominator <- function(denominator,
                                         statfin,
                                         statfin_codes,
                                         years = as.character(2019:2023)) {
  rows <- lapply(seq_len(nrow(denominator)), function(i) {
    code <- denominator$occupation[[i]]
    packaged <- denominator$employment[[i]]
    applicable <- code %in% statfin_codes
    year_values <- stats::setNames(rep(NA_real_, length(years)), years)
    if (applicable) {
      sub <- statfin[statfin$occupation == code, , drop = FALSE]
      for (year in years) {
        hit <- sub$employment[sub$year == year]
        if (length(hit) == 1L) year_values[[year]] <- hit
      }
    }
    complete <- applicable && !anyNA(year_values)
    mean_value <- if (complete) mean(year_values) else NA_real_
    rounded <- if (complete) round_to_thousand(mean_value) else NA_real_
    status <- if (!applicable) {
      "not_in_statfin"
    } else if (!complete) {
      "incomplete"
    } else if (isTRUE(all.equal(rounded, packaged))) {
      "match"
    } else {
      "unexplained_difference"
    }
    data.frame(
      occupation = code,
      packaged_employment = packaged,
      statfin_2019 = unname(year_values[["2019"]]),
      statfin_2020 = unname(year_values[["2020"]]),
      statfin_2021 = unname(year_values[["2021"]]),
      statfin_2022 = unname(year_values[["2022"]]),
      statfin_2023 = unname(year_values[["2023"]]),
      statfin_mean = mean_value,
      rounded_mean = rounded,
      difference = if (is.na(rounded)) NA_real_ else packaged - rounded,
      status = status,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Finnish sentences describing the saved denominator audit.
#'
#' @param comparison Comparison data frame.
#' @param audit Audit metadata list.
#' @return Character vector.
#' @export
worklife_audit_paragraphs <- function(comparison, audit) {
  n_match <- sum(comparison$status == "match")
  n_diff <- sum(comparison$status == "unexplained_difference")
  n_missing <- sum(comparison$status == "not_in_statfin")
  n_incomplete <- sum(comparison$status == "incomplete")
  compared <- paste0(
    "Paketin nimittäjää verrattiin Tilastokeskuksen taulukkoon 115s ",
    "haussa, joka tehtiin ", audit$retrieved_at, ". ",
    "Vertailussa oli ", nrow(comparison), " ammattiluokkaa: ",
    n_match, " täsmäsi pyöristettyyn vuosien 2019–2023 keskiarvoon, ",
    n_diff, " erosi siitä, ",
    n_incomplete, " jäi vajaaksi ja ",
    n_missing, " ei ole StatFin-luokassa."
  )
  if (n_diff > 0L) {
    codes <- comparison$occupation[comparison$status == "unexplained_difference"]
    compared <- paste0(
      compared, " Selittämättömät erot koskevat koodeja ",
      paste(codes, collapse = ", "),
      ". Paketin nimittäjää ei korvattu uudemmalla StatFin-luvulla."
    )
  } else if (n_incomplete > 0L || !isTRUE(audit$verification_complete)) {
    compared <- paste0(
      compared,
      " Varmistus jäi osittain vajaaksi, joten suhdeluvut esitetään tällä varauksella."
    )
  } else {
    compared <- paste0(
      compared,
      " Täsmäävät koodit vastaavat pyöristettyä keskimääräistä työllisten määrää ",
      "juuri tässä haussa. Taulukon myöhempi päivitys voi silti poiketa paketin ",
      "27.4.2026 otteesta, eikä paketin lukuja vaihdettu."
    )
  }
  qualifiers <- c(
    compared,
    audit$age_note,
    audit$geography_note,
    audit$reference_note,
    audit$classification_note
  )
  qualifiers[!is.na(qualifiers) & nzchar(qualifiers)]
}
