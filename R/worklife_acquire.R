#' Names stored in a zip archive.
#'
#' @param zip Path to a zip file.
#' @return Character vector of member names.
#' @export
worklife_archive_members <- function(zip) {
  utils::unzip(zip, list = TRUE)$Name
}

#' Stop unless every expected member is in the archive.
#'
#' @param zip Path to a zip file.
#' @param expected Character vector of member names.
#' @return The member listing, invisibly.
#' @export
assert_worklife_archive_members <- function(zip, expected) {
  found <- worklife_archive_members(zip)
  missing <- setdiff(expected, found)
  if (length(missing) > 0L) {
    stop(
      "Pinned archive is missing expected members: ",
      paste(missing, collapse = ", ")
    )
  }
  invisible(found)
}

#' Keep a verified download only after size, checksum and members match.
#'
#' On failure the destination is left unchanged and the pin is not edited.
#'
#' @param temp_path Temporary download.
#' @param dest_path Snapshot path to retain.
#' @param expected_bytes Pinned size.
#' @param expected_sha256 Pinned SHA-256.
#' @param expected_members Archive members that must exist.
#' @return Destination path.
#' @export
commit_verified_snapshot <- function(temp_path,
                                     dest_path,
                                     expected_bytes,
                                     expected_sha256,
                                     expected_members) {
  assessment <- assess_worklife_file(
    temp_path, expected_bytes, expected_sha256
  )
  if (!isTRUE(assessment$ok)) {
    stop(
      "Downloaded file does not match the pin (", assessment$reason,
      "). The existing snapshot and the pin were not changed."
    )
  }
  assert_worklife_archive_members(temp_path, expected_members)
  dest_dir <- dirname(dest_path)
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)
  ok <- file.copy(temp_path, dest_path, overwrite = TRUE)
  if (!isTRUE(ok)) stop("Could not retain the verified snapshot at ", dest_path)
  dest_path
}

#' Write the retrieval record next to the analysis, not into the pin.
#'
#' @param pin Pin list.
#' @param provenance_path Output yml path.
#' @param retrieved_at POSIXct or character timestamp.
#' @return The path written.
#' @export
write_worklife_provenance <- function(pin, provenance_path, retrieved_at = Sys.time()) {
  if (!requireNamespace("yaml", quietly = TRUE)) stop("Package 'yaml' is required.")
  if (!dir.exists(dirname(provenance_path))) {
    dir.create(dirname(provenance_path), recursive = TRUE)
  }
  stamp <- format(as.POSIXct(retrieved_at), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  record <- list(
    retrieved_at = stamp,
    url = pin$url,
    bytes = pin$expected_bytes,
    sha256 = tolower(pin$sha256),
    licence = pin$licence,
    licence_url = pin$licence_url,
    publisher = pin$publisher,
    service = pin$service,
    dataset = pin$dataset,
    handover_date = pin$handover_date,
    period = pin$period,
    dataset_page = pin$dataset_page,
    attribution = pin$attribution,
    statfin_table = pin$statfin_table,
    statfin_readme_retrieved = pin$statfin_readme_retrieved
  )
  yaml::write_yaml(record, provenance_path)
  provenance_path
}

#' Download the pinned zip, verify it, and retain it only if it matches.
#'
#' @param root Project root.
#' @param pin Optional pin list. Read from disk when omitted.
#' @return Snapshot path.
#' @export
acquire_worklife_snapshot <- function(root = ".", pin = NULL) {
  paths <- worklife_paths(root)
  if (is.null(pin)) pin <- worklife_read_pin(paths$pin)
  tmp <- tempfile(fileext = ".zip")
  on.exit(unlink(tmp), add = TRUE)
  old_timeout <- getOption("timeout")
  options(timeout = max(300, as.numeric(old_timeout)))
  on.exit(options(timeout = old_timeout), add = TRUE)
  status <- utils::download.file(pin$url, tmp, mode = "wb", quiet = TRUE, method = "libcurl")
  if (!identical(status, 0L)) {
    stop("Download failed with status ", status, ". Existing snapshot was not changed.")
  }
  retrieved_at <- Sys.time()
  dest <- commit_verified_snapshot(
    tmp,
    paths$snapshot_zip,
    pin$expected_bytes,
    pin$sha256,
    unlist(pin$archive_members, use.names = FALSE)
  )
  write_worklife_provenance(pin, paths$provenance, retrieved_at)
  message("Retained verified snapshot: ", dest)
  dest
}
