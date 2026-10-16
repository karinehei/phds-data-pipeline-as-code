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
summary_df <- as.data.frame(result)
# A skipped test has passed == 0. The snapshot check is skipped in CI
# because the verified zip is not in the repository.
if (any(summary_df$failed > 0) || any(summary_df$error)) {
  stop("Some tests failed")
}
invisible(result)
