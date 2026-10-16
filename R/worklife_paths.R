#' Project-relative paths for the worklife analysis.
#'
#' @param root Project root. Defaults to the working directory.
#' @return Named list of paths.
#' @export
worklife_paths <- function(root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  list(
    root = root,
    pin = file.path(root, "data_contract", "worklife_source.yml"),
    codebook_csv = file.path(root, "data_contract", "worklife_codebook.csv"),
    codebook_meta = file.path(root, "data_contract", "worklife_codebook.yml"),
    snapshot_dir = file.path(root, "data", "raw", "worklife"),
    snapshot_zip = file.path(
      root, "data", "raw", "worklife",
      "occupational-diseases-data-20052026.zip"
    ),
    provenance = file.path(root, "data", "worklife", "provenance.yml"),
    audit_dir = file.path(root, "data", "worklife", "audit"),
    output_dir = file.path(root, "output", "worklife")
  )
}

#' Read the pinned source description.
#'
#' @param path Path to \code{worklife_source.yml}, or a project root if the
#'   file is not given directly. Pass the yml path.
#' @return List.
#' @export
worklife_read_pin <- function(path = "data_contract/worklife_source.yml") {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required.")
  }
  if (!file.exists(path)) stop("Worklife pin not found: ", path)
  pin <- yaml::read_yaml(path)
  required <- c("url", "expected_bytes", "sha256", "covid_label",
                "expected_case_rows", "expected_covid_rows", "archive_members")
  missing <- setdiff(required, names(pin))
  if (length(missing) > 0L) {
    stop("Worklife pin is missing: ", paste(missing, collapse = ", "))
  }
  pin$expected_bytes <- as.numeric(pin$expected_bytes)
  pin$expected_case_rows <- as.integer(pin$expected_case_rows)
  pin$expected_covid_rows <- as.integer(pin$expected_covid_rows)
  pin
}
