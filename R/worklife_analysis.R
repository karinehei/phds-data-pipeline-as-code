#' Rank high values as 1. Ties share the minimum rank and the next rank is skipped.
#'
#' @param x Numeric vector. \code{NA} stays \code{NA}.
#' @return Integer vector.
#' @export
rank_high_min <- function(x) {
  out <- rep(NA_integer_, length(x))
  ok <- !is.na(x)
  if (!any(ok)) return(out)
  out[ok] <- as.integer(rank(-x[ok], ties.method = "min", na.last = "keep"))
  out
}

#' Employment-normalised five-year count per 1,000 employed.
#'
#' Undefined when the case count is missing or the denominator is not positive.
#' A zero retained count in a diagnosis subset is a real zero, not a missing value.
#'
#' @param cases Retained case counts.
#' @param employment Packaged denominator.
#' @return Numeric vector.
#' @export
period_cases_per_1000 <- function(cases, employment) {
  out <- rep(NA_real_, length(cases))
  ok <- !is.na(cases) & !is.na(employment) & employment > 0
  out[ok] <- 1000 * cases[ok] / employment[ok]
  out
}

#' Occupation-level counts, packaged denominators, ratios and tied ranks.
#'
#' Repeated input rows are cases. This function does not call \code{unique()}.
#' An occupation that is only in the denominator is absent from the released
#' case extract: its case counts stay missing rather than becoming zero.
#'
#' @param cases Validated case data frame.
#' @param denominator Validated denominator.
#' @param codebook Codebook.
#' @param covid_label Exact COVID-19 diagnosis string.
#' @param coarse_employment_max Denominators at or below this are flagged.
#' @return List with \code{table} and \code{meta}.
#' @export
occupation_metrics <- function(cases,
                               denominator,
                               codebook,
                               covid_label = "COVID-19-infektio",
                               coarse_employment_max = 10000) {
  validate_worklife_cases(cases, codebook)
  validate_worklife_denominator(denominator)
  labels <- occupation_labels(codebook, "occupation")

  case_codes <- sort(unique(cases$AMMATTI))
  den_codes <- denominator$occupation
  codes <- sort(union(case_codes, den_codes))
  in_extract <- codes %in% case_codes

  covid <- is_covid_diagnosis(cases$DIAGNOOSI, covid_label)
  n_cases <- rep(NA_integer_, length(codes))
  n_covid <- rep(NA_integer_, length(codes))
  n_other <- rep(NA_integer_, length(codes))
  for (i in which(in_extract)) {
    rows <- cases$AMMATTI == codes[[i]]
    n_cases[[i]] <- as.integer(sum(rows))
    n_covid[[i]] <- as.integer(sum(rows & covid))
    n_other[[i]] <- as.integer(sum(rows & !covid))
  }
  if (!all(n_cases[in_extract] == n_covid[in_extract] + n_other[in_extract])) {
    stop("All-case counts are not equal to COVID plus other-diagnosis counts")
  }

  employment <- rep(NA_real_, length(codes))
  den_index <- match(codes, denominator$occupation)
  has_den <- !is.na(den_index)
  employment[has_den] <- denominator$employment[den_index[has_den]]

  denominator_status <- ifelse(
    !has_den, "missing",
    ifelse(employment == 0, "zero", "positive")
  )
  ratio <- period_cases_per_1000(n_cases, employment)
  ratio_covid <- period_cases_per_1000(n_covid, employment)
  ratio_other <- period_cases_per_1000(n_other, employment)

  label_index <- match(codes, labels$code)
  if (anyNA(label_index)) {
    stop("Occupation codes missing from the codebook: ",
         paste(codes[is.na(label_index)], collapse = ", "))
  }

  exclusion <- ifelse(
    !in_extract, "ei julkaistussa tapausotteessa",
    ifelse(denominator_status == "missing", "puuttuva nimittäjä",
           ifelse(denominator_status == "zero", "nimittäjä on nolla", ""))
  )

  table <- data.frame(
    occupation = codes,
    label_fi = labels$label_fi[label_index],
    label_en = labels$label_en[label_index],
    in_case_extract = in_extract,
    n_cases = n_cases,
    n_covid = n_covid,
    n_other = n_other,
    employment = employment,
    denominator_status = denominator_status,
    period_cases_per_1000 = ratio,
    period_covid_per_1000 = ratio_covid,
    period_other_per_1000 = ratio_other,
    annualised_cases_per_1000 = ratio / 5,
    rank_count = rank_high_min(as.numeric(n_cases)),
    rank_ratio = rank_high_min(ratio),
    rank_count_other = rank_high_min(as.numeric(n_other)),
    rank_ratio_other = rank_high_min(ratio_other),
    coarse_denominator = !is.na(employment) & employment > 0 &
      employment <= coarse_employment_max,
    exclusion_reason = exclusion,
    stringsAsFactors = FALSE
  )
  table <- table[order(table$rank_count, table$occupation, na.last = TRUE), , drop = FALSE]
  rownames(table) <- NULL

  meta <- list(
    tie_method = "min",
    coarse_employment_max = coarse_employment_max,
    n_case_rows = nrow(cases),
    n_unique_case_rows = nrow(unique(cases)),
    n_covid_rows = sum(covid),
    n_other_rows = sum(!covid),
    n_occupations_in_extract = sum(in_extract),
    n_ratio_defined = sum(!is.na(ratio)),
    counts_reconcile = TRUE,
    ratio_definition = "1000 * retained_case_count / packaged_employment_denominator"
  )
  list(table = table, meta = meta)
}

#' Exposure-group counts for leading non-COVID occupations.
#'
#' Unobserved occupation-exposure pairs are omitted. They are not filled with zero,
#' because suppression can remove small cells.
#'
#' @param cases Case data frame.
#' @param metrics Result of \code{occupation_metrics()}.
#' @param codebook Codebook.
#' @param covid_label COVID label to exclude.
#' @param max_rank Occupations with \code{rank_ratio_other} at most this value.
#' @return Data frame of retained non-COVID counts.
#' @export
exposure_composition <- function(cases,
                                 metrics,
                                 codebook,
                                 covid_label = "COVID-19-infektio",
                                 max_rank = 6L) {
  tab <- metrics$table
  leaders <- tab[!is.na(tab$rank_ratio_other) & tab$rank_ratio_other <= max_rank, , drop = FALSE]
  if (nrow(leaders) == 0L) {
    return(data.frame(
      occupation = character(),
      label_fi = character(),
      exposure = character(),
      exposure_fi = character(),
      n = integer(),
      stringsAsFactors = FALSE
    ))
  }
  keep <- !is_covid_diagnosis(cases$DIAGNOOSI, covid_label) &
    cases$AMMATTI %in% leaders$occupation
  sub <- cases[keep, , drop = FALSE]
  if (nrow(sub) == 0L) {
    return(data.frame(
      occupation = character(),
      label_fi = character(),
      exposure = character(),
      exposure_fi = character(),
      n = integer(),
      stringsAsFactors = FALSE
    ))
  }
  pairs <- unique(sub[, c("AMMATTI", "ALTISTERYHMA"), drop = FALSE])
  n <- integer(nrow(pairs))
  for (i in seq_len(nrow(pairs))) {
    n[[i]] <- as.integer(sum(
      sub$AMMATTI == pairs$AMMATTI[[i]] &
        sub$ALTISTERYHMA == pairs$ALTISTERYHMA[[i]]
    ))
  }
  exp_labels <- occupation_labels(codebook, "exposure")
  occ_labels <- occupation_labels(codebook, "occupation")
  data.frame(
    occupation = pairs$AMMATTI,
    label_fi = occ_labels$label_fi[match(pairs$AMMATTI, occ_labels$code)],
    exposure = pairs$ALTISTERYHMA,
    exposure_fi = exp_labels$label_fi[match(pairs$ALTISTERYHMA, exp_labels$code)],
    n = n,
    stringsAsFactors = FALSE
  )
}

#' Rows that share the best rank in one column.
#'
#' @param table Metrics table.
#' @param rank_col Rank column name.
#' @return Data frame.
#' @export
rank_leaders <- function(table, rank_col) {
  ranks <- table[[rank_col]]
  if (all(is.na(ranks))) return(table[0, , drop = FALSE])
  best <- min(ranks, na.rm = TRUE)
  out <- table[!is.na(ranks) & ranks == best, , drop = FALSE]
  out[order(out$occupation), , drop = FALSE]
}

#' Format an integer with a narrow space as the thousands separator.
#'
#' @param x Number.
#' @return Character.
#' @export
format_fi_int <- function(x) {
  format(as.integer(round(x)), big.mark = "\u00a0", scientific = FALSE, trim = TRUE)
}

#' Format a ratio with one decimal and a Finnish decimal comma.
#'
#' @param x Number.
#' @param digits Decimal places.
#' @return Character.
#' @export
format_fi_num <- function(x, digits = 1) {
  format(
    round(x, digits),
    nsmall = digits,
    decimal.mark = ",",
    big.mark = "\u00a0",
    scientific = FALSE,
    trim = TRUE
  )
}

#' One Finnish sentence listing rank leaders.
#'
#' @param leaders Data frame from \code{rank_leaders()}.
#' @param value_col Column to print.
#' @param value_fmt \code{"int"} or \code{"num"}.
#' @return Character scalar.
#' @export
format_leaders_fi <- function(leaders, value_col, value_fmt = "int") {
  parts <- vapply(seq_len(nrow(leaders)), function(i) {
    value <- leaders[[value_col]][[i]]
    shown <- if (value_fmt == "int") format_fi_int(value) else format_fi_num(value)
    paste0(leaders$label_fi[[i]], " (", leaders$occupation[[i]], ", ", shown, ")")
  }, character(1))
  paste(parts, collapse = " ja ")
}

#' Finnish executive summary computed from the occupation table.
#'
#' @param metrics Result of \code{occupation_metrics()}.
#' @return Character vector of paragraphs.
#' @export
worklife_executive_paragraphs <- function(metrics) {
  tab <- metrics$table
  count_leaders <- rank_leaders(tab, "rank_count")
  ratio_leaders <- rank_leaders(tab, "rank_ratio")
  other_count <- rank_leaders(tab, "rank_count_other")
  other_ratio <- rank_leaders(tab, "rank_ratio_other")

  count_sentence <- paste0(
    "Julkaistussa vuosien 2019–2023 otteessa säilytettyjä vahvistettuja ",
    "ammattitautitapauksia on eniten ammattiluokassa ",
    format_leaders_fi(count_leaders, "n_cases", "int"),
    ". Tässä luvussa on mukana ",
    format_fi_int(sum(count_leaders$n_covid)),
    " COVID-19-infektioksi kirjattua säilytettyä tapausta",
    if (nrow(count_leaders) == 1L) " tässä ammattiluokassa." else "."
  )
  ratio_detail <- ""
  if (nrow(ratio_leaders) == 1L) {
    ratio_detail <- paste0(
      " Nimittäjänä on ",
      format_fi_int(ratio_leaders$employment[[1L]]),
      " työllistä ja osoittajana ",
      format_fi_int(ratio_leaders$n_cases[[1L]]),
      " säilytettyä tapausta."
    )
  }
  ratio_sentence <- paste0(
    "Korkein työllisten lukumäärään suhteutettu viiden vuoden suhdeluku on ",
    format_fi_num(ratio_leaders$period_cases_per_1000[[1L]]),
    " säilytettyä tapausta tuhatta työllistä kohden",
    if (nrow(ratio_leaders) == 1L) " ammattiluokassa " else " ammattiluokissa ",
    paste0(ratio_leaders$label_fi, " (", ratio_leaders$occupation, ")", collapse = " ja "),
    ".",
    ratio_detail
  )
  other_sentence <- paste0(
    "Kun COVID-19-infektio erotetaan, muiden diagnoosien lukumäärän kärjessä on ",
    format_fi_int(other_count$n_other[[1L]]),
    " säilytettyä tapausta",
    if (nrow(other_count) == 1L) " ammattiluokassa " else " ammattiluokissa ",
    paste0(other_count$label_fi, " (", other_count$occupation, ")", collapse = " ja "),
    ". Suhdeluvun kärjessä on ",
    format_fi_num(other_ratio$period_other_per_1000[[1L]]),
    " säilytettyä tapausta tuhatta työllistä kohden",
    if (nrow(other_ratio) == 1L) " ammattiluokassa " else " ammattiluokissa ",
    paste0(other_ratio$label_fi, " (", other_ratio$occupation, ")", collapse = " ja "),
    "."
  )
  definition <- paste0(
    "Suhdeluku on julkaistujen tapausten määrä suhteessa paketin työllisyysnimittäjään: ",
    "tuhat kertaa viiden vuoden säilytetyt tapaukset jaettuna paketin työllisten lukumäärällä. ",
    "Se ei ole vuotuinen ilmaantuvuus, yksilön todennäköisyys eikä kausaalinen riski, ",
    "eikä suoraan vertailukelpoinen väestösuhde. Viidellä jakaminen olisi vain ",
    "viitteellinen vuositasolle jaettu kuvailusuhde, koska tapauksiin ei ole liitetty henkilöaikaa."
  )
  limits <- paste0(
    "Luvut kuvaavat julkaistua otetta, eivät yksittäisiä ihmisiä eivätkä rekisterin ",
    "täydellistä kansallista kokonaismäärää. Alle viiden tapauksen solut on poistettu, ",
    "ja samalle tapaukselle kirjatuista taudeista on säilytetty vakavin. ",
    "Aineistosta puuttuvaa ammattiluokkaa ei tulkita nollaksi. ",
    "Tuhannen tarkkuinen nimittäjä ja poistetut pienet solut voivat muuttaa järjestystä."
  )
  c(count_sentence, ratio_sentence, other_sentence, definition, limits)
}
