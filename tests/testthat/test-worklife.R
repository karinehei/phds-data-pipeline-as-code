# Offline tests for the occupational-disease analysis.
# The pinned zip is optional: snapshot checks skip when it has not been acquired.

mini_codebook <- function() {
  data.frame(
    domain = c(
      "occupation", "occupation", "occupation", "occupation", "occupation",
      "exposure", "exposure"
    ),
    code = c("01", "53", "61", "ZZ", "11", "2", "7"),
    label_fi = c(
      "Upseerit", "Hoiva", "Maatalous", "Opiskelijat", "Johtajat",
      "Biologiset", "Melu"
    ),
    label_en = c(
      "Officers", "Care", "Farm", "Students", "Managers",
      "Biological", "Noise"
    ),
    stringsAsFactors = FALSE
  )
}

test_that("occupation codes keep leading zeros and quote marks are removed", {
  expect_equal(normalise_occupation_code("'01'"), "01")
  expect_equal(normalise_occupation_code("01"), "01")
  expect_equal(normalise_occupation_code("ZZ"), "ZZ")
  path <- tempfile(fileext = ".tsv")
  writeLines(
    c(
      "DIAGNOOSI\tALTISTERYHMA\tAMMATTI",
      "\"Meluvamma\"\t7\t\"01\"",
      "\"Meluvamma\"\t7\t\"01\""
    ),
    path,
    useBytes = TRUE
  )
  df <- read_worklife_table(
    path, "\t", c("DIAGNOOSI", "ALTISTERYHMA", "AMMATTI")
  )
  expect_identical(df$AMMATTI, c("01", "01"))
  expect_equal(nrow(df), 2L)
})

test_that("repeated case rows are kept and COVID is an exact label", {
  cases <- data.frame(
    DIAGNOOSI = c(
      "COVID-19-infektio", "COVID-19-infektio", "COVID-19-infektio",
      "Meluvamma", "COVID-19"
    ),
    ALTISTERYHMA = c("2", "2", "2", "7", "2"),
    AMMATTI = c("53", "53", "53", "01", "53"),
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = c("01", "53"),
    employment = c(5000, 2000),
    stringsAsFactors = FALSE
  )
  metrics <- occupation_metrics(cases, denominator, mini_codebook())
  row <- metrics$table[metrics$table$occupation == "53", ]
  expect_equal(row$n_cases, 4L)
  expect_equal(row$n_covid, 3L)
  expect_equal(row$n_other, 1L)
  expect_equal(row$n_cases, row$n_covid + row$n_other)
  expect_false(is_covid_diagnosis("COVID-19"))
  expect_true(is_covid_diagnosis("COVID-19-infektio"))
  expect_equal(metrics$meta$n_case_rows, 5L)
  expect_gt(metrics$meta$n_case_rows, metrics$meta$n_unique_case_rows)
})

test_that("ratios and tied ranks match a hand calculation", {
  cases <- data.frame(
    DIAGNOOSI = c(
      rep("Meluvamma", 10),
      rep("Meluvamma", 10),
      rep("COVID-19-infektio", 4)
    ),
    ALTISTERYHMA = c(rep("7", 20), rep("2", 4)),
    AMMATTI = c(rep("01", 10), rep("53", 10), rep("61", 4)),
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = c("01", "53", "61"),
    employment = c(5000, 5000, 4000),
    stringsAsFactors = FALSE
  )
  tab <- occupation_metrics(cases, denominator, mini_codebook())$table
  expect_equal(tab$period_cases_per_1000[tab$occupation == "01"], 2)
  expect_equal(tab$period_cases_per_1000[tab$occupation == "53"], 2)
  expect_equal(tab$period_cases_per_1000[tab$occupation == "61"], 1)
  expect_equal(tab$rank_count[tab$occupation == "01"], 1L)
  expect_equal(tab$rank_count[tab$occupation == "53"], 1L)
  expect_equal(tab$rank_count[tab$occupation == "61"], 3L)
  expect_equal(tab$rank_ratio[tab$occupation == "01"], 1L)
  expect_equal(tab$rank_ratio[tab$occupation == "53"], 1L)
  expect_equal(tab$annualised_cases_per_1000[tab$occupation == "01"], 0.4)
})

test_that("missing, zero and absent occupations stay distinct", {
  cases <- data.frame(
    DIAGNOOSI = c("COVID-19-infektio", "COVID-19-infektio", "Meluvamma"),
    ALTISTERYHMA = c("2", "2", "7"),
    AMMATTI = c("53", "53", "ZZ"),
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = c("53", "11", "01"),
    employment = c(2000, 8000, 0),
    stringsAsFactors = FALSE
  )
  tab <- occupation_metrics(cases, denominator, mini_codebook())$table
  absent <- tab[tab$occupation == "11", ]
  expect_false(absent$in_case_extract)
  expect_true(is.na(absent$n_cases))
  expect_equal(absent$employment, 8000)
  expect_true(is.na(absent$period_cases_per_1000))
  expect_equal(absent$exclusion_reason, "ei julkaistussa tapausotteessa")

  zero_den <- tab[tab$occupation == "01", ]
  expect_false(zero_den$in_case_extract)
  expect_equal(zero_den$denominator_status, "zero")
  expect_true(is.na(zero_den$n_cases))

  missing_den <- tab[tab$occupation == "ZZ", ]
  expect_true(missing_den$in_case_extract)
  expect_equal(missing_den$n_cases, 1L)
  expect_equal(missing_den$denominator_status, "missing")
  expect_true(is.na(missing_den$employment))
  expect_true(is.na(missing_den$period_cases_per_1000))
  expect_equal(missing_den$exclusion_reason, "puuttuva nimittäjä")

  subset_zero <- tab[tab$occupation == "53", ]
  expect_equal(subset_zero$n_covid, 2L)
  expect_equal(subset_zero$n_other, 0L)
  expect_equal(subset_zero$period_other_per_1000, 0)
})

test_that("a zero denominator in the extract has no ratio", {
  cases <- data.frame(
    DIAGNOOSI = "Meluvamma",
    ALTISTERYHMA = "7",
    AMMATTI = "01",
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = "01", employment = 0, stringsAsFactors = FALSE
  )
  tab <- occupation_metrics(cases, denominator, mini_codebook())$table
  expect_equal(tab$n_cases, 1L)
  expect_equal(tab$denominator_status, "zero")
  expect_true(is.na(tab$period_cases_per_1000))
  expect_equal(tab$exclusion_reason, "nimittäjä on nolla")
})

test_that("duplicate denominator keys and label joins are rejected", {
  cases <- data.frame(
    DIAGNOOSI = c("Meluvamma", "Meluvamma"),
    ALTISTERYHMA = c("7", "7"),
    AMMATTI = c("01", "01"),
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = c("01", "01"),
    employment = c(1000, 2000),
    stringsAsFactors = FALSE
  )
  expect_error(
    occupation_metrics(cases, denominator, mini_codebook()),
    "Duplicate denominator"
  )
  book <- mini_codebook()
  book <- rbind(book, book[book$code == "01", ])
  denominator <- data.frame(
    occupation = "01", employment = 1000, stringsAsFactors = FALSE
  )
  expect_error(
    occupation_metrics(cases, denominator, book),
    "Duplicate occupation labels"
  )
})

test_that("checksum or size mismatch does not replace an existing snapshot", {
  dest <- tempfile(fileext = ".zip")
  writeBin(charToRaw("ORIGINAL"), dest)
  temp <- tempfile(fileext = ".zip")
  writeBin(charToRaw("BADDATA!!"), temp)
  expect_error(
    commit_verified_snapshot(
      temp, dest,
      expected_bytes = 9,
      expected_sha256 = paste(rep("a", 64), collapse = ""),
      expected_members = "variables.xlsx"
    ),
    "does not match the pin"
  )
  expect_equal(rawToChar(readBin(dest, raw(), 20)), "ORIGINAL")
  expect_error(
    commit_verified_snapshot(
      temp, dest,
      expected_bytes = 999,
      expected_sha256 = worklife_file_sha256(temp),
      expected_members = "variables.xlsx"
    ),
    "does not match the pin"
  )
  expect_equal(rawToChar(readBin(dest, raw(), 20)), "ORIGINAL")
})

test_that("snapshot integrity assertions use the supplied pin, not a hidden total", {
  pin <- list(
    expected_case_rows = 2L,
    expected_covid_rows = 1L,
    covid_label = "COVID-19-infektio"
  )
  cases <- data.frame(
    DIAGNOOSI = c("COVID-19-infektio", "Meluvamma"),
    stringsAsFactors = FALSE
  )
  expect_invisible(assert_pinned_snapshot(cases, pin))
  expect_error(assert_pinned_snapshot(cases[1, , drop = FALSE], pin), "integrity")
})

test_that("rounding to thousands matches the planned half-away-from-zero rule", {
  expect_equal(round_to_thousand(44256.8), 44000)
  expect_equal(round_to_thousand(5032.8), 5000)
  expect_equal(round_to_thousand(195745), 196000)
  expect_equal(round_to_thousand(233.6), 0)
})

test_that("the Finnish summary names the ratio and refuses an incidence reading", {
  cases <- data.frame(
    DIAGNOOSI = c(rep("COVID-19-infektio", 3), "Meluvamma"),
    ALTISTERYHMA = c("2", "2", "2", "7"),
    AMMATTI = c("53", "53", "53", "01"),
    stringsAsFactors = FALSE
  )
  denominator <- data.frame(
    occupation = c("53", "01"),
    employment = c(3000, 1000),
    stringsAsFactors = FALSE
  )
  text <- paste(worklife_executive_paragraphs(
    occupation_metrics(cases, denominator, mini_codebook())
  ), collapse = " ")
  expect_match(text, "ei ole vuotuinen ilmaantuvuus")
  expect_match(text, "Hoiva")
  expect_false(grepl("todennäköisyys on", text))
})

test_that("codebook headings do not confuse disease with occupation", {
  expect_equal(
    worklife_codebook_domain("Ammattitauti / Occupational disease / Yrkessjukdom"),
    "diagnosis"
  )
  expect_equal(
    worklife_codebook_domain("Ammattiluokitus / Occupation / Yrke"),
    "occupation"
  )
})

test_that("pinned snapshot keeps repeated rows and the expected COVID count", {
  zip <- worklife_paths(testthat::test_path("..", ".."))$snapshot_zip
  skip_if_not(file.exists(zip), "verified snapshot has not been acquired")
  pin <- worklife_read_pin(testthat::test_path("..", "..", "data_contract", "worklife_source.yml"))
  cases <- read_worklife_cases(zip, pin$case_member)
  expect_equal(nrow(cases), 6096L)
  expect_equal(sum(is_covid_diagnosis(cases$DIAGNOOSI, pin$covid_label)), 2940L)
  expect_gt(nrow(cases), nrow(unique(cases)))
  denominator <- read_worklife_denominator(zip, pin$denominator_member)
  expect_true("01" %in% denominator$occupation)
  expect_equal(length(unique(denominator$occupation)), nrow(denominator))
})
