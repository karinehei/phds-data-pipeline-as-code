# Extract Finnish and English labels from variables.xlsx in the pinned zip.
# Run from the repository root after make worklife-acquire:
#   Rscript scripts/extract_worklife_codebook.R

root <- "."
if (!file.exists(file.path(root, "data_contract", "worklife_source.yml"))) {
  stop("Run this script from the repository root.")
}

source(file.path(root, "R", "worklife_hash.R"))
source(file.path(root, "R", "worklife_paths.R"))
source(file.path(root, "R", "worklife_codebook.R"))

paths <- worklife_paths(root)
pin <- worklife_read_pin(paths$pin)
if (!file.exists(paths$snapshot_zip)) {
  stop("Verified snapshot not found. Run: Rscript scripts/acquire_worklife.R")
}

assessment <- assess_worklife_file(
  paths$snapshot_zip, pin$expected_bytes, pin$sha256
)
if (!isTRUE(assessment$ok)) stop(assessment$reason)

xlsx <- file.path(tempdir(), "variables.xlsx")
extract_zip_member(paths$snapshot_zip, pin$codebook_member, xlsx)
table <- extract_codebook_table(xlsx)

if (!dir.exists(dirname(paths$codebook_csv))) {
  dir.create(dirname(paths$codebook_csv), recursive = TRUE)
}
utils::write.csv(
  table,
  paths$codebook_csv,
  row.names = FALSE,
  fileEncoding = "UTF-8",
  na = ""
)
reread <- read_worklife_codebook(paths$codebook_csv)
if (!codebook_tables_identical(table, reread)) {
  stop("Consistency check failed: the CSV round-trip changed codebook values.")
}

meta <- list(
  source_zip = pin$url,
  source_zip_sha256 = tolower(pin$sha256),
  source_zip_bytes = pin$expected_bytes,
  source_member = pin$codebook_member,
  source_member_sha256 = worklife_file_sha256(xlsx),
  extracted_by = "scripts/extract_worklife_codebook.R",
  n_rows = nrow(table),
  domains = as.list(sort(unique(table$domain)))
)
yaml::write_yaml(meta, paths$codebook_meta)
message(
  "Wrote ", paths$codebook_csv, " (", nrow(table),
  " rows) and ", paths$codebook_meta
)
