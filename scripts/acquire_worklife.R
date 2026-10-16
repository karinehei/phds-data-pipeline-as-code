# Download the pinned occupational-disease snapshot.
# Run from the repository root:
#   Rscript scripts/acquire_worklife.R

root <- "."
if (!file.exists(file.path(root, "data_contract", "worklife_source.yml"))) {
  stop("Run this script from the repository root.")
}
source(file.path(root, "R", "worklife_hash.R"))
source(file.path(root, "R", "worklife_paths.R"))
source(file.path(root, "R", "worklife_acquire.R"))
acquire_worklife_snapshot(root)
