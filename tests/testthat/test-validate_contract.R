# Unit tests for contract validation
# Assumes wd is project root; R/ sourced by run-tests.R
# testthat runs from tests/testthat, so use test_path() for project-root files

contract_path <- function() {
  # test_path is relative to tests/testthat; go up to project root
  p <- testthat::test_path("..", "..", "data_contract", "contract.yaml")
  if (!file.exists(p)) stop("Cannot find data_contract/contract.yaml")
  p
}

# Valid minimal df for contract
valid_df <- function(n = 2) {
  data.frame(
    patient_id = paste0("P", seq_len(n)),
    age_years = rep(5L, n),
    sex = rep("M", n),
    visit_date = rep(as.Date("2024-01-01"), n),
    diagnosis_code = rep("J06.9", n),
    site_id = rep("SITE_A", n),
    weight_kg = rep(20, n),
    stringsAsFactors = FALSE
  )
}

test_that("validate_against_contract catches missing required column", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  df <- data.frame(patient_id = "P1", age_years = 5L)
  res <- validate_against_contract(df, contract)
  expect_false(res$valid)
  expect_true(any(grepl("Missing required", res$errors)))
})

test_that("validate_against_contract catches invalid age_years", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  df <- valid_df(1)
  df$age_years <- 25L
  res <- validate_against_contract(df, contract)
  expect_false(res$valid)
  expect_true(any(grepl("age_years", res$errors)))
})

test_that("validate_against_contract catches invalid sex enum", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  df <- valid_df(1)
  df$sex <- "X"
  res <- validate_against_contract(df, contract)
  expect_false(res$valid)
  expect_true(any(grepl("sex", res$errors)))
})

test_that("validate_against_contract passes valid data", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  res <- validate_against_contract(valid_df(), contract)
  expect_true(res$valid)
  expect_length(res$errors, 0)
})

test_that("validate_against_contract adds warning when weight_kg missing exceeds threshold", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  df <- valid_df(20)
  df$weight_kg <- rep(NA_real_, 20)
  res <- validate_against_contract(df, contract, weight_missing_threshold = 0.2)
  expect_true(res$valid)
  expect_true(length(res$warnings) > 0)
  expect_true(any(grepl("weight_kg", res$warnings)))
})

test_that("validate_against_contract no warning when weight_kg missing below threshold", {
  skip_if_not_installed("yaml")
  contract <- read_contract(contract_path())
  df <- valid_df(20)
  df$weight_kg[1:2] <- NA_real_
  res <- validate_against_contract(df, contract, weight_missing_threshold = 0.2)
  expect_true(res$valid)
  expect_length(res$warnings, 0)
})

test_that("check_required_columns catches missing columns", {
  df <- data.frame(a = 1)
  rc <- check_required_columns(df, c("a", "b", "c"))
  expect_false(rc$ok)
  expect_true(grepl("Missing", rc$errors) || grepl("b", rc$errors) || grepl("c", rc$errors))
})

test_that("check_range catches out-of-range values", {
  df <- data.frame(x = c(1, 5, 20))
  rc <- check_range(df, "x", min_val = 0, max_val = 10)
  expect_false(rc$ok)
})

test_that("check_enum catches invalid values", {
  df <- data.frame(sex = c("M", "X", "F"))
  ec <- check_enum(df, "sex", c("M", "F", "Other", "Unknown"))
  expect_false(ec$ok)
})

test_that("check_missing_rate adds warning when threshold exceeded", {
  df <- data.frame(w = c(1, NA, NA, NA, NA))
  mr <- check_missing_rate(df, "w", threshold = 0.2)
  expect_false(mr$ok)
  expect_true(grepl("80", mr$warnings))
})

test_that("print_validation_summary runs without error", {
  res <- list(valid = TRUE, errors = character(0), warnings = character(0))
  expect_error(print_validation_summary(res), NA)
  expect_output(print_validation_summary(res), "PASS")
  res2 <- list(valid = FALSE, errors = "Bad", warnings = "Warning")
  expect_output(print_validation_summary(res2), "FAIL")
})

test_that("validate_contract stops on error when stop_on_error=TRUE", {
  skip_if_not_installed("yaml")
  bad_df <- data.frame(x = 1)
  expect_error(
    validate_contract(bad_df, contract_path = contract_path(), stop_on_error = TRUE),
    "Contract validation failed"
  )
})
