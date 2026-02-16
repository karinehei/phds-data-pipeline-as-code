#!/usr/bin/env Rscript
# Run tests from project root: Rscript run-tests.R
# Fast, deterministic; no package structure required.

root <- if (file.exists("tests/testthat")) "." else {
  if (file.exists("../tests/testthat")) ".." else stop("Run from project root")
}
setwd(root)

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

result <- testthat::test_dir("tests/testthat", reporter = "summary")
if (!all(as.data.frame(result)$passed)) stop("Some tests failed")
invisible(result)
