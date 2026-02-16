# testthat infrastructure for phds-data-pipeline-as-code
# Run via: Rscript run-tests.R  OR  R -e "source('run-tests.R')"  OR  make test
# Assumes wd is project root.

library(testthat)

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# test_dir() is invoked by run-tests.R; this file exists for testthat::test_check()
# when used as a package (future). For project tests, use run-tests.R.
