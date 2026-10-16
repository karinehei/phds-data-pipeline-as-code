#' Strip the quote marks Excel stored around occupation codes such as \code{'01'}.
#'
#' @param x Character vector.
#' @return Character vector.
#' @export
normalise_occupation_code <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub("^'+|'+$", "", x)
  trimws(x)
}

#' Map a codebook section heading to a domain name.
#'
#' \code{Occupational disease} is tested before \code{Occupation} because the
#' former contains the latter as text.
#'
#' @param text Heading text.
#' @return Domain name, or \code{NA}.
#' @export
worklife_codebook_domain <- function(text) {
  text <- as.character(text)
  if (length(text) != 1L || is.na(text)) return(NA_character_)
  if (grepl("Occupational disease", text, fixed = TRUE)) return("diagnosis")
  if (grepl("Exposure agent", text, fixed = TRUE)) return("exposure")
  if (grepl("Occupation", text, fixed = TRUE)) return("occupation")
  if (grepl("Industry", text, fixed = TRUE)) return("industry")
  if (grepl("Sex", text, fixed = TRUE)) return("sex")
  if (grepl("Region", text, fixed = TRUE)) return("region")
  NA_character_
}

#' Parse \code{variables.xlsx} sheet 1 into a code table.
#'
#' @param xlsx_path Path to the workbook.
#' @return Data frame with \code{domain}, \code{code}, \code{label_fi},
#'   \code{label_en}.
#' @export
extract_codebook_table <- function(xlsx_path) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required to read variables.xlsx.")
  }
  raw <- readxl::read_excel(
    xlsx_path, sheet = 1, col_names = FALSE, col_types = "text"
  )
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  if (ncol(raw) < 3L) stop("variables.xlsx does not have the expected columns")
  domain <- NA_character_
  rows <- vector("list", nrow(raw))
  n <- 0L
  for (i in seq_len(nrow(raw))) {
    head <- raw[[1L]][[i]]
    label_fi <- raw[[2L]][[i]]
    label_en <- raw[[3L]][[i]]
    if (is.na(head) || !nzchar(head)) next
    if (grepl(" / ", head, fixed = TRUE) && (is.na(label_fi) || !nzchar(label_fi))) {
      domain <- worklife_codebook_domain(head)
      next
    }
    if (is.na(domain) || is.na(label_fi) || !nzchar(label_fi)) next
    n <- n + 1L
    code <- if (identical(domain, "occupation")) {
      normalise_occupation_code(head)
    } else {
      trimws(head)
    }
    rows[[n]] <- data.frame(
      domain = domain,
      code = code,
      label_fi = trimws(label_fi),
      label_en = if (is.na(label_en)) "" else trimws(label_en),
      stringsAsFactors = FALSE
    )
  }
  if (n == 0L) stop("No codebook rows were read from ", xlsx_path)
  out <- do.call(rbind, rows[seq_len(n)])
  out <- out[order(out$domain, out$code), , drop = FALSE]
  rownames(out) <- NULL
  if (anyDuplicated(paste(out$domain, out$code, sep = "\r")) > 0L) {
    stop("Codebook has duplicate domain/code pairs")
  }
  out
}

#' Read a committed codebook CSV without dropping leading zeros.
#'
#' @param path CSV path.
#' @return Data frame.
#' @export
read_worklife_codebook <- function(path = "data_contract/worklife_codebook.csv") {
  df <- utils::read.csv(
    path,
    colClasses = "character",
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8",
    na.strings = character(0)
  )
  need <- c("domain", "code", "label_fi", "label_en")
  missing <- setdiff(need, names(df))
  if (length(missing) > 0L) {
    stop("Codebook CSV is missing columns: ", paste(missing, collapse = ", "))
  }
  df[order(df$domain, df$code), need, drop = FALSE]
}

#' Extract \code{variables.xlsx} from the pinned zip.
#'
#' @param zip Snapshot path.
#' @param member Member name.
#' @param dest File path for the extracted workbook.
#' @return \code{dest}.
#' @export
extract_zip_member <- function(zip, member, dest) {
  if (!dir.exists(dirname(dest))) dir.create(dirname(dest), recursive = TRUE)
  tmp <- tempfile("worklife-member-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(zip, files = member, exdir = tmp)
  found <- file.path(tmp, member)
  if (!file.exists(found)) stop("Archive member not extracted: ", member)
  if (!file.copy(found, dest, overwrite = TRUE)) {
    stop("Could not write ", dest)
  }
  dest
}

#' Compare two codebook tables as characters.
#'
#' @param a Data frame.
#' @param b Data frame.
#' @return \code{TRUE} when domain, code and labels match in order.
#' @export
codebook_tables_identical <- function(a, b) {
  cols <- c("domain", "code", "label_fi", "label_en")
  if (!all(cols %in% names(a)) || !all(cols %in% names(b))) return(FALSE)
  a <- a[order(a$domain, a$code), cols, drop = FALSE]
  b <- b[order(b$domain, b$code), cols, drop = FALSE]
  rownames(a) <- NULL
  rownames(b) <- NULL
  identical(
    lapply(a, as.character),
    lapply(b, as.character)
  )
}

#' Rebuild the codebook from the zip and stop if it differs from the CSV.
#'
#' @param zip Snapshot path.
#' @param csv Committed CSV path.
#' @param member Workbook member name.
#' @return The extracted table.
#' @export
assert_codebook_matches_zip <- function(zip,
                                        csv,
                                        member = "variables.xlsx") {
  dest <- file.path(tempdir(), "worklife-variables.xlsx")
  extract_zip_member(zip, member, dest)
  on.exit(unlink(dest), add = TRUE)
  extracted <- extract_codebook_table(dest)
  committed <- read_worklife_codebook(csv)
  if (!codebook_tables_identical(extracted, committed)) {
    stop(
      "data_contract/worklife_codebook.csv does not match variables.xlsx ",
      "in the pinned snapshot. Re-run scripts/extract_worklife_codebook.R ",
      "and review the diff."
    )
  }
  extracted
}
