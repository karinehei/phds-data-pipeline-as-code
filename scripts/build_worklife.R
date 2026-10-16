# Build the offline worklife report from the verified snapshot and saved audit.
# Run from the repository root:
#   Rscript scripts/build_worklife.R

root <- "."
if (!file.exists(file.path(root, "_targets_worklife.R"))) {
  stop("Run this script from the repository root.")
}
win_quarto <- "C:/Program Files/Quarto/bin"
if (dir.exists(win_quarto)) {
  Sys.setenv(PATH = paste(win_quarto, Sys.getenv("PATH"), sep = ";"))
}
targets::tar_make(
  script = "_targets_worklife.R",
  store = "_targets_worklife"
)
