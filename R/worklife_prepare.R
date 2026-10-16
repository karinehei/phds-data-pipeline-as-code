#' Read one TSV/DSV member from the snapshot zip.
#'
#' Occupation-like columns are forced to character so leading zeros survive.
#'
#' @param zip Snapshot path.
#' @param member Archive member.
#' @param sep Field separator.
#' @param character_cols Columns stored as character.
#' @return Data frame.
#' @export
read_worklife_table <- function(path, sep, character_cols) {
  col_classes <- rep("character", length(character_cols))
  names(col_classes) <- character_cols
  df <- utils::read.delim(
    path,
    sep = sep,
    quote = "\"",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8",
    colClasses = col_classes
  )
  names(df) <- sub("^\ufeff", "", names(df))
  df
}

read_worklife_member <- function(zip, member, sep, character_cols) {
  tmp <- tempfile("worklife-read-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(zip, files = member, exdir = tmp)
  path <- file.path(tmp, member)
  if (!file.exists(path)) stop("Could not read archive member ", member)
  read_worklife_table(path, sep, character_cols)
}

#' Read file A without dropping repeated case rows.
#'
#' @param zip Snapshot path.
#' @param member Member name.
#' @return Data frame with \code{DIAGNOOSI}, \code{ALTISTERYHMA}, \code{AMMATTI}.
#' @export
read_worklife_cases <- function(zip,
                                member = "data_2019_2023/data_A_2019_2023.tsv") {
  df <- read_worklife_member(
    zip, member, sep = "\t",
    character_cols = c("DIAGNOOSI", "ALTISTERYHMA", "AMMATTI")
  )
  need <- c("DIAGNOOSI", "ALTISTERYHMA", "AMMATTI")
  missing <- setdiff(need, names(df))
  if (length(missing) > 0L) {
    stop("Case file is missing columns: ", paste(missing, collapse = ", "))
  }
  df$DIAGNOOSI <- trimws(df$DIAGNOOSI)
  df$ALTISTERYHMA <- trimws(df$ALTISTERYHMA)
  df$AMMATTI <- normalise_occupation_code(df$AMMATTI)
  df[, need, drop = FALSE]
}

#' Read the packaged occupation denominator.
#'
#' @param zip Snapshot path.
#' @param member Member name.
#' @return Data frame with \code{occupation} and \code{employment}.
#' @export
read_worklife_denominator <- function(
    zip,
    member = "data_2019_2023/workersPerOccupation_2019_2023.dsv") {
  df <- read_worklife_member(
    zip, member, sep = ";",
    character_cols = c("AMMATTI", "TYONTEKIJOITA")
  )
  if (!all(c("AMMATTI", "TYONTEKIJOITA") %in% names(df))) {
    stop("Denominator file must contain AMMATTI and TYONTEKIJOITA")
  }
  employment <- suppressWarnings(as.numeric(df$TYONTEKIJOITA))
  out <- data.frame(
    occupation = normalise_occupation_code(df$AMMATTI),
    employment = employment,
    stringsAsFactors = FALSE
  )
  out
}

#' Exact COVID-19 label used in the pinned extract.
#'
#' @param diagnosis Character vector.
#' @param label Exact diagnosis string.
#' @return Logical vector.
#' @export
is_covid_diagnosis <- function(diagnosis, label = "COVID-19-infektio") {
  !is.na(diagnosis) & diagnosis == label
}

#' Snapshot-integrity checks for the pinned file. These are not analysis results.
#'
#' @param cases Case data frame.
#' @param pin Pin list.
#' @return \code{cases}, invisibly.
#' @export
assert_pinned_snapshot <- function(cases, pin) {
  n <- nrow(cases)
  n_covid <- sum(is_covid_diagnosis(cases$DIAGNOOSI, pin$covid_label))
  if (!identical(as.integer(n), as.integer(pin$expected_case_rows))) {
    stop(
      "Snapshot integrity failed: file A has ", n,
      " rows; the pin expects ", pin$expected_case_rows, "."
    )
  }
  if (!identical(as.integer(n_covid), as.integer(pin$expected_covid_rows))) {
    stop(
      "Snapshot integrity failed: COVID-19 rows = ", n_covid,
      "; the pin expects ", pin$expected_covid_rows, "."
    )
  }
  invisible(cases)
}

#' Validate cases against the codebook. Does not deduplicate rows.
#'
#' @param cases Case data frame.
#' @param codebook Codebook data frame.
#' @return \code{cases}, invisibly.
#' @export
validate_worklife_cases <- function(cases, codebook) {
  need <- c("DIAGNOOSI", "ALTISTERYHMA", "AMMATTI")
  missing <- setdiff(need, names(cases))
  if (length(missing) > 0L) {
    stop("Cases are missing columns: ", paste(missing, collapse = ", "))
  }
  if (!is.character(cases$AMMATTI)) {
    stop("Occupation codes must be character, so leading zeros are preserved.")
  }
  if (anyNA(cases$DIAGNOOSI) || any(!nzchar(cases$DIAGNOOSI))) {
    stop("DIAGNOOSI has empty values")
  }
  if (anyNA(cases$ALTISTERYHMA) || any(!nzchar(cases$ALTISTERYHMA))) {
    stop("ALTISTERYHMA has empty values")
  }
  if (anyNA(cases$AMMATTI) || any(!nzchar(cases$AMMATTI))) {
    stop("AMMATTI has empty values")
  }
  exposure_codes <- codebook$code[codebook$domain == "exposure"]
  occupation_codes <- codebook$code[codebook$domain == "occupation"]
  bad_exp <- unique(setdiff(cases$ALTISTERYHMA, exposure_codes))
  bad_occ <- unique(setdiff(cases$AMMATTI, occupation_codes))
  if (length(bad_exp) > 0L) {
    stop("Unknown exposure codes: ", paste(bad_exp, collapse = ", "))
  }
  if (length(bad_occ) > 0L) {
    stop("Unknown occupation codes: ", paste(bad_occ, collapse = ", "))
  }
  invisible(cases)
}

#' Validate the denominator: unique keys and non-negative employment.
#'
#' @param denominator Data frame with \code{occupation} and \code{employment}.
#' @return \code{denominator}, invisibly.
#' @export
validate_worklife_denominator <- function(denominator) {
  if (!all(c("occupation", "employment") %in% names(denominator))) {
    stop("Denominator must have columns occupation and employment")
  }
  if (!is.character(denominator$occupation)) {
    stop("Denominator occupation codes must be character")
  }
  if (anyNA(denominator$occupation) || any(!nzchar(denominator$occupation))) {
    stop("Denominator has empty occupation codes")
  }
  if (anyDuplicated(denominator$occupation) > 0L) {
    dup <- unique(denominator$occupation[duplicated(denominator$occupation)])
    stop(
      "Duplicate denominator occupation keys: ",
      paste(dup, collapse = ", "),
      ". A join would multiply case rows."
    )
  }
  if (anyNA(denominator$employment) || any(denominator$employment < 0)) {
    stop("Employment denominators must be non-missing and non-negative")
  }
  invisible(denominator)
}

#' Stop if occupation labels are duplicated. A label join must not multiply rows.
#'
#' @param codebook Codebook data frame.
#' @param domain Domain to check.
#' @return Label data frame with unique codes.
#' @export
occupation_labels <- function(codebook, domain = "occupation") {
  labels <- codebook[codebook$domain == domain, c("code", "label_fi", "label_en"), drop = FALSE]
  if (anyDuplicated(labels$code) > 0L) {
    stop("Duplicate ", domain, " labels; joining them would multiply rows")
  }
  labels
}
