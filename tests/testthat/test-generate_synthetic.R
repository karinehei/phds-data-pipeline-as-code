# Unit tests for generate_synthetic_data() and generate_demo_data()
# Assumes wd is project root; R/ sourced by run-tests.R

# Required columns per contract
REQUIRED_COLS <- c("patient_id", "age_years", "sex", "visit_date", "diagnosis_code", "site_id", "weight_kg")

# Allowed values
ALLOWED_SEX <- c("M", "F", "Other", "Unknown")
ALLOWED_SITES <- c("SITE_A", "SITE_B", "SITE_C", "SITE_D")

test_that("generate_synthetic_data produces required columns", {
  df <- generate_synthetic_data(10, 30, seed = 42, out_path_parquet = NULL)
  expect_true(all(REQUIRED_COLS %in% names(df)))
  expect_equal(ncol(df), length(REQUIRED_COLS))
})

test_that("generate_synthetic_data respects age_years range 0-18", {
  df <- generate_synthetic_data(50, 150, seed = 123, out_path_parquet = NULL)
  expect_true(all(df$age_years >= 0 & df$age_years <= 18, na.rm = TRUE))
  expect_true(is.integer(df$age_years) || all(df$age_years == as.integer(df$age_years)))
})

test_that("generate_synthetic_data respects sex enum", {
  df <- generate_synthetic_data(30, 80, seed = 99, out_path_parquet = NULL)
  expect_true(all(df$sex %in% ALLOWED_SEX))
})

test_that("generate_synthetic_data respects site_id enum", {
  df <- generate_synthetic_data(20, 60, seed = 1, out_path_parquet = NULL)
  expect_true(all(df$site_id %in% ALLOWED_SITES))
})

test_that("generate_synthetic_data weight_kg in range when present", {
  df <- generate_synthetic_data(40, 120, seed = 777, out_path_parquet = NULL)
  present <- df$weight_kg[!is.na(df$weight_kg)]
  if (length(present) > 0) {
    expect_true(all(present >= 2 & present <= 200))
  }
})

test_that("generate_synthetic_data produces reproducible output", {
  df1 <- generate_synthetic_data(50, 200, seed = 42, out_path_parquet = NULL)
  df2 <- generate_synthetic_data(50, 200, seed = 42, out_path_parquet = NULL)
  expect_identical(df1, df2)
})

test_that("generate_synthetic_data produces different output for different seeds", {
  df1 <- generate_synthetic_data(50, 200, seed = 1, out_path_parquet = NULL)
  df2 <- generate_synthetic_data(50, 200, seed = 2, out_path_parquet = NULL)
  expect_false(identical(df1, df2))
})

test_that("generate_synthetic_data writes parquet when path given", {
  skip_if_not_installed("arrow")
  tmp <- tempfile(fileext = ".parquet")
  on.exit(unlink(tmp, force = TRUE))
  df <- generate_synthetic_data(10, 30, seed = 99, out_path_parquet = tmp)
  expect_true(file.exists(tmp))
  df2 <- as.data.frame(arrow::read_parquet(tmp))
  expect_equal(df, df2)
})
