#' SHA-256 of a file, as a lowercase hex string.
#'
#' @param path Path to an existing file.
#' @return Character scalar.
#' @export
worklife_file_sha256 <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Package 'digest' is required to verify the snapshot.")
  }
  digest::digest(file = path, algo = "sha256")
}

#' File size in bytes.
#'
#' @param path Path to an existing file.
#' @return Numeric scalar.
#' @export
worklife_file_bytes <- function(path) {
  info <- file.info(path)
  if (is.na(info$size)) stop("Cannot read file size: ", path)
  as.numeric(info$size)
}

#' Compare a downloaded file with the pinned size and checksum.
#'
#' Does not write or delete anything.
#'
#' @param path File to assess.
#' @param expected_bytes Expected size.
#' @param expected_sha256 Expected SHA-256 hex string.
#' @return List with \code{ok}, \code{bytes}, \code{sha256}, and \code{reason}.
#' @export
assess_worklife_file <- function(path, expected_bytes, expected_sha256) {
  if (!file.exists(path)) {
    return(list(ok = FALSE, bytes = NA_real_, sha256 = NA_character_,
                reason = paste0("File does not exist: ", path)))
  }
  bytes <- worklife_file_bytes(path)
  sha <- worklife_file_sha256(path)
  expected_sha256 <- tolower(expected_sha256)
  reasons <- character(0)
  if (!isTRUE(all.equal(bytes, as.numeric(expected_bytes)))) {
    reasons <- c(reasons, paste0(
      "size ", bytes, " does not match pinned size ", expected_bytes
    ))
  }
  if (!identical(tolower(sha), expected_sha256)) {
    reasons <- c(reasons, paste0(
      "SHA-256 ", sha, " does not match pinned SHA-256 ", expected_sha256
    ))
  }
  list(
    ok = length(reasons) == 0L,
    bytes = bytes,
    sha256 = sha,
    reason = paste(reasons, collapse = "; ")
  )
}
