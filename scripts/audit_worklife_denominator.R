# Compare the packaged denominator with StatFin table 115s.
# This is a live query. The offline report only reads the files written here.
# Run from the repository root, after acquisition:
#   Rscript scripts/audit_worklife_denominator.R

root <- "."
if (!file.exists(file.path(root, "data_contract", "worklife_source.yml"))) {
  stop("Run this script from the repository root.")
}

source(file.path(root, "R", "worklife_hash.R"))
source(file.path(root, "R", "worklife_paths.R"))
source(file.path(root, "R", "worklife_codebook.R"))
source(file.path(root, "R", "worklife_prepare.R"))
source(file.path(root, "R", "worklife_audit.R"))

paths <- worklife_paths(root)
pin <- worklife_read_pin(paths$pin)
if (!file.exists(paths$snapshot_zip)) {
  stop("Verified snapshot not found. Run scripts/acquire_worklife.R first.")
}
assessment <- assess_worklife_file(paths$snapshot_zip, pin$expected_bytes, pin$sha256)
if (!isTRUE(assessment$ok)) stop(assessment$reason)

denominator <- read_worklife_denominator(paths$snapshot_zip, pin$denominator_member)
validate_worklife_denominator(denominator)

dir.create(paths$audit_dir, recursive = TRUE, showWarnings = FALSE)
retrieved_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

meta_raw <- worklife_fetch_json(pin$statfin_api)
writeLines(meta_raw$text, file.path(paths$audit_dir, "metadata.json"), useBytes = TRUE)
meta <- jsonlite::fromJSON(meta_raw$text, simplifyVector = FALSE)

occupation <- worklife_meta_variable(meta, "Ammatti")
area <- worklife_meta_variable(meta, "alue")
year <- worklife_meta_variable(meta, "^Vuosi$")
sex <- worklife_meta_variable(meta, "Sukupuoli")

whole_country <- worklife_value_code(area, "^KOKO MAA$")
both_sexes <- worklife_value_code(sex, "^Yhteens")
all_occupations <- worklife_value_code(occupation, "^Ammattiryhm")
aland_code <- worklife_value_code(area, "Ahvenanmaa|\u00c5land")
aland_label <- unlist(area$valueTexts)[match(aland_code, unlist(area$values))]

statfin_codes <- unlist(occupation$values)
query_codes <- denominator$occupation[denominator$occupation %in% statfin_codes]
years <- as.character(2019:2023)
missing_years <- setdiff(years, unlist(year$values))
if (length(missing_years) > 0L) {
  stop("StatFin table is missing years: ", paste(missing_years, collapse = ", "))
}

occ_query <- worklife_px_query(stats::setNames(
  list(query_codes, whole_country, years, both_sexes),
  c(occupation$code, area$code, year$code, sex$code)
))
writeLines(
  jsonlite::toJSON(occ_query, auto_unbox = FALSE, pretty = TRUE),
  file.path(paths$audit_dir, "query.json"),
  useBytes = TRUE
)
occ_raw <- worklife_fetch_json(pin$statfin_api, occ_query)
writeLines(occ_raw$text, file.path(paths$audit_dir, "response.json"), useBytes = TRUE)
occ_data <- parse_px_data(occ_raw$text)
# Key order follows the query: occupation, area, year, sex.
statfin <- data.frame(
  occupation = occ_data$k1,
  year = occ_data$k3,
  employment = occ_data$value,
  stringsAsFactors = FALSE
)
comparison <- compare_packaged_denominator(denominator, statfin, statfin_codes, years)
utils::write.csv(
  comparison,
  file.path(paths$audit_dir, "comparison.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

region_values <- unlist(area$values)
region_query <- worklife_px_query(stats::setNames(
  list(all_occupations, region_values, years, both_sexes),
  c(occupation$code, area$code, year$code, sex$code)
))
writeLines(
  jsonlite::toJSON(region_query, auto_unbox = FALSE, pretty = TRUE),
  file.path(paths$audit_dir, "region_query.json"),
  useBytes = TRUE
)
region_raw <- worklife_fetch_json(pin$statfin_api, region_query)
writeLines(region_raw$text, file.path(paths$audit_dir, "region_response.json"), useBytes = TRUE)
region_data <- parse_px_data(region_raw$text)
region_df <- data.frame(
  area = region_data$k2,
  year = region_data$k3,
  employment = region_data$value,
  stringsAsFactors = FALSE
)

geography_ok <- TRUE
geography_note <- paste0(
  "Taulukon aluemääre sisältää arvon ", whole_country,
  " (koko maa) ja alueen ", aland_code, " (", aland_label, ")."
)
for (yr in years) {
  total <- region_df$employment[region_df$area == whole_country & region_df$year == yr]
  parts <- region_df$employment[region_df$area != whole_country & region_df$year == yr]
  if (length(total) != 1L || anyNA(parts) || !isTRUE(all.equal(sum(parts), total))) {
    geography_ok <- FALSE
  }
}
aland_rows <- region_df[region_df$area == aland_code, , drop = FALSE]
if (isTRUE(geography_ok)) {
  geography_note <- paste0(
    geography_note,
    " Vuosina 2019–2023 alueiden summa vastaa koko maan lukua, joten koko maan ",
    "nimittäjä sisältää Ahvenanmaan. Ahvenanmaan työllisten keskiarvo on ",
    round(mean(aland_rows$employment)),
    ". Tapausote ei sisällä Ahvenanmaata."
  )
} else {
  geography_note <- paste0(
    geography_note,
    " Alueiden summa ei täsmännyt koko maan lukuun, joten Ahvenanmaan osuutta ",
    "paketin nimittäjässä ei vahvistettu."
  )
}

docs_note <- "Työssäkäyntitilaston dokumentaatiota ei saatu haettua."
age_note <- paste0(
  "Taulukossa 115s ei ole ikämuuttujaa. Tapausotteen kuvaus rajaa tapaukset ",
  "15–64-vuotiaisiin."
)
reference_note <- "Viiteajankohtaa ei luettu dokumentaatiosta tässä ajossa."
classification_note <- paste0(
  "Ammattimuuttuja on ", occupation$text, " (", occupation$code, ")."
)
docs_path <- file.path(paths$audit_dir, "definitions_extract.txt")
docs_ok <- FALSE
docs_try <- tryCatch({
  lines <- readLines(pin$statfin_docs, encoding = "UTF-8", warn = FALSE)
  text <- paste(lines, collapse = "\n")
  plain <- gsub("<[^>]+>", " ", text)
  plain <- gsub("[[:space:]]+", " ", plain)
  patterns <- c("18-74", "18\u201374", "viimeisell", "Ammattiluokitus", "ammattiluokitus")
  excerpts <- character()
  for (pattern in patterns) {
    hits <- gregexpr(pattern, plain, ignore.case = TRUE)[[1L]]
    if (hits[[1L]] < 0L) next
    taken <- 0L
    for (pos in hits) {
      if (taken >= 2L) break
      start <- max(1L, pos - 160L)
      end <- min(nchar(plain), pos + 220L)
      excerpts <- c(excerpts, paste0("[", pattern, "] ", substr(plain, start, end)))
      taken <- taken + 1L
    }
  }
  excerpts <- unique(excerpts)
  if (length(excerpts) == 0L) excerpts <- "No definition phrases matched."
  writeLines(excerpts, docs_path, useBytes = TRUE)
  docs_ok <- TRUE
  plain
}, error = function(e) e$message)
if (isTRUE(docs_ok)) {
  docs_note <- "Työssäkäyntitilaston dokumentaatio haettiin osoitteesta stat.fi."
  if (grepl("18-74|18–74", docs_try)) {
    age_note <- paste0(
      age_note,
      " Haettu dokumentaatio määrittelee työlliset 18–74-vuotiaiksi. ",
      "Ikärajat eivät siis ole samat."
    )
  }
  if (grepl("viimeisell", docs_try, ignore.case = TRUE)) {
    reference_note <- paste0(
      "Dokumentaation mukaan väestö kuvataan vuoden viimeisen päivän tilannetta ",
      "ja toiminta vuoden viimeistä viikkoa."
    )
  }
  if (grepl("Ammattiluokitus|ammattiluokitus", docs_try)) {
    classification_note <- paste0(
      classification_note,
      " Dokumentaatio sanoo, että ammateissa käytetään kulloinkin voimassa olevaa ",
      "Tilastokeskuksen ammattiluokitusta. Paketin README nimeää luokituksen AML 2010."
    )
  }
} else {
  writeLines(as.character(docs_try), docs_path, useBytes = TRUE)
}

n_bad <- sum(comparison$status %in% c("unexplained_difference", "incomplete"))
verification_complete <- n_bad == 0L && isTRUE(geography_ok) && isTRUE(docs_ok)

audit <- list(
  retrieved_at = retrieved_at,
  statfin_api = pin$statfin_api,
  statfin_docs = pin$statfin_docs,
  table_title = meta$title,
  occupation_variable = occupation$code,
  area_variable = area$code,
  year_variable = year$code,
  sex_variable = sex$code,
  whole_country_code = whole_country,
  both_sexes_code = both_sexes,
  all_occupations_code = all_occupations,
  aland_code = aland_code,
  aland_label = aland_label,
  aland_mean_employment = if (nrow(aland_rows) == length(years)) mean(aland_rows$employment) else NA_real_,
  geography_sums_match = geography_ok,
  verification_complete = verification_complete,
  n_match = sum(comparison$status == "match"),
  n_unexplained_difference = sum(comparison$status == "unexplained_difference"),
  n_not_in_statfin = sum(comparison$status == "not_in_statfin"),
  n_incomplete = sum(comparison$status == "incomplete"),
  age_note = age_note,
  geography_note = geography_note,
  reference_note = reference_note,
  classification_note = classification_note,
  docs_note = docs_note,
  packaged_denominator_replaced = FALSE
)
yaml::write_yaml(audit, file.path(paths$audit_dir, "audit.yml"))
message(
  "Denominator audit: ", audit$n_match, " match, ",
  audit$n_unexplained_difference, " unexplained, ",
  audit$n_not_in_statfin, " not in StatFin."
)
