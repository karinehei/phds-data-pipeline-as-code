#' Wrap long Finnish labels for axis text.
#'
#' @param x Character vector.
#' @param width Target line width.
#' @return Character vector.
#' @export
wrap_fi <- function(x, width = 32) {
  vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) return("")
    paste(strwrap(s, width = width), collapse = "\n")
  }, character(1))
}

#' Shared plot theme.
#'
#' @return A ggplot2 theme.
#' @export
theme_worklife <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 13),
      plot.subtitle = ggplot2::element_text(size = 10, colour = "grey25"),
      plot.caption = ggplot2::element_text(size = 8, colour = "grey30", hjust = 0),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin = ggplot2::margin(10, 16, 12, 10),
      legend.position = "bottom",
      legend.box.margin = ggplot2::margin(4, 0, 0, 0),
      panel.grid.minor = ggplot2::element_blank()
    )
}

worklife_source_caption <- function() {
  paste(
    "Lähde: Työterveyslaitos, Työelämätieto, luovutettu 20.5.2026 (CC BY 4.0).",
    "Nimittäjä: Tilastokeskus, työssäkäyntitilasto, taulukko 115s (CC BY 4.0).",
    sep = "\n"
  )
}

worklife_ratio_caption <- function() {
  paste(
    "Julkaistujen tapausten määrä suhteessa paketin työllisyysnimittäjään.",
    "Tapaukset: 15–64-vuotiaat, ilman Ahvenanmaata. Nimittäjä: 18–74-vuotiaat, koko maa mukaan lukien Ahvenanmaa.",
    "Tuhannen pyöristys ja poistetut pienet solut voivat muuttaa järjestystä.",
    "Ei yksilön riski, vuotuinen ilmaantuvuus eikä vertailukelpoinen väestösuhde.",
    worklife_source_caption(),
    sep = "\n"
  )
}

#' Rows whose rank is within the plotted head, including ties at the boundary.
#'
#' @param table Metrics table.
#' @param rank_col Rank column.
#' @param max_rank Maximum rank to include.
#' @return Data frame.
#' @keywords internal
slice_by_rank <- function(table, rank_col, max_rank) {
  ranks <- table[[rank_col]]
  table[!is.na(ranks) & ranks <= max_rank, , drop = FALSE]
}

#' Stacked counts of COVID-19 and other retained diagnoses.
#'
#' @param table Metrics table.
#' @param max_rank Head of the count ranking to draw.
#' @return ggplot object.
#' @export
plot_count_split <- function(table, max_rank = 12L) {
  top <- slice_by_rank(table, "rank_count", max_rank)
  top <- top[order(top$n_cases, top$occupation), , drop = FALSE]
  long <- rbind(
    data.frame(
      label = top$label_fi, n = top$n_other,
      group = "Muut diagnoosit", stringsAsFactors = FALSE
    ),
    data.frame(
      label = top$label_fi, n = top$n_covid,
      group = "COVID-19-infektio", stringsAsFactors = FALSE
    )
  )
  long$label <- factor(
    wrap_fi(long$label, 34),
    levels = wrap_fi(unique(top$label_fi), 34)
  )
  long$group <- factor(long$group, levels = c("Muut diagnoosit", "COVID-19-infektio"))
  ggplot2::ggplot(long, ggplot2::aes(x = .data$label, y = .data$n, fill = .data$group)) +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.55, 0.55))) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = c(
      "Muut diagnoosit" = "#1F4E79",
      "COVID-19-infektio" = "#F0B429"
    )) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05))) +
    ggplot2::labs(
      title = "Säilytetyt tapaukset ammattiluokittain",
      subtitle = "Vuosien 2019–2023 julkaistu ote. Järjestys lukumäärän mukaan, tasatilanteet mukana.",
      x = NULL,
      y = "Säilytettyjen tapausten lukumäärä",
      fill = NULL,
      caption = worklife_source_caption()
    ) +
    theme_worklife()
}

#' Employment-normalised five-year values for the leading occupations.
#'
#' @param table Metrics table.
#' @param max_rank Head of the ratio ranking.
#' @return ggplot object.
#' @export
plot_period_ratio <- function(table, max_rank = 12L) {
  top <- slice_by_rank(table, "rank_ratio", max_rank)
  top <- top[order(top$period_cases_per_1000, top$occupation), , drop = FALSE]
  top$label <- factor(wrap_fi(top$label_fi, 34), levels = wrap_fi(unique(top$label_fi), 34))
  top$coarse_label <- ifelse(top$coarse_denominator, "Nimittäjä enintään 10 000", "Nimittäjä yli 10 000")
  ggplot2::ggplot(
    top,
    ggplot2::aes(x = .data$label, y = .data$period_cases_per_1000, fill = .data$coarse_label)
  ) +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.55, 0.55))) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = c(
      "Nimittäjä yli 10 000" = "#0F6C6C",
      "Nimittäjä enintään 10 000" = "#C47B2B"
    )) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.06))) +
    ggplot2::labs(
      title = "Julkaistut tapaukset suhteessa paketin työllisyysnimittäjään",
      subtitle = "1 000 × viiden vuoden säilytetyt tapaukset / paketin työllisten lukumäärä.",
      x = NULL,
      y = "Säilytetyt tapaukset / 1 000 työllistä",
      fill = NULL,
      caption = paste(
        "Oranssi palkki: nimittäjä on pyöristetty enintään 10 000 työlliseen.",
        worklife_ratio_caption(),
        sep = "\n"
      )
    ) +
    theme_worklife()
}

#' Count rank against the normalised rank, with and without COVID-19.
#'
#' @param table Metrics table.
#' @return ggplot object.
#' @export
plot_rank_slope <- function(table) {
  panels <- list(
    "Kaikki diagnoosit" = c("rank_count", "rank_ratio"),
    "Ilman COVID-19-infektiota" = c("rank_count_other", "rank_ratio_other")
  )
  pieces <- lapply(names(panels), function(panel) {
    cols <- panels[[panel]]
    keep <- !is.na(table[[cols[[1L]]]]) & !is.na(table[[cols[[2L]]]])
    sub <- table[keep, , drop = FALSE]
    rbind(
      data.frame(
        panel = panel, occupation = sub$occupation, label = sub$label_fi,
        metric = "Lukumäärä", rank = sub[[cols[[1L]]]],
        stringsAsFactors = FALSE
      ),
      data.frame(
        panel = panel, occupation = sub$occupation, label = sub$label_fi,
        metric = "Suhdeluku", rank = sub[[cols[[2L]]]],
        stringsAsFactors = FALSE
      )
    )
  })
  long <- do.call(rbind, pieces)
  long$metric <- factor(long$metric, levels = c("Lukumäärä", "Suhdeluku"))
  long$panel <- factor(long$panel, levels = names(panels))
  # Label occupations that are in the top 8 of either axis in that panel.
  long$show_label <- FALSE
  for (panel in levels(long$panel)) {
    idx <- long$panel == panel
    best <- tapply(long$rank[idx], long$occupation[idx], min)
    leaders <- names(best)[best <= 8]
    long$show_label[idx] <- long$occupation[idx] %in% leaders & long$metric[idx] == "Suhdeluku"
  }
  labelled <- long[long$show_label, , drop = FALSE]
  labelled$label_text <- paste0(
    labelled$occupation, " ",
    ifelse(
      nchar(labelled$label) > 36,
      paste0(substr(labelled$label, 1, 35), "\u2026"),
      labelled$label
    )
  )
  max_rank <- max(long$rank, na.rm = TRUE)
  ggplot2::ggplot(
    long,
    ggplot2::aes(x = .data$metric, y = .data$rank, group = .data$occupation)
  ) +
    ggplot2::geom_line(colour = "#9AA5B1", linewidth = 0.45) +
    ggplot2::geom_point(colour = "#1F4E79", size = 2) +
    ggplot2::geom_text(
      data = labelled,
      ggplot2::aes(label = .data$label_text),
      hjust = 0, nudge_x = 0.08, size = 2.35, colour = "grey15"
    ) +
    ggplot2::facet_wrap(ggplot2::vars(.data$panel), ncol = 1) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.25, 1.7))) +
    ggplot2::scale_y_reverse(
      limits = c(0.4, max_rank + 0.8),
      breaks = c(1, 5, 10, 15, 20, 25, 30)
    ) +
    ggplot2::labs(
      title = "Lukumäärän ja suhdeluvun järjestys",
      subtitle = "Sama järjestysluku tarkoittaa tasatilannetta. Seuraava sija hyppää yli.",
      x = NULL,
      y = "Järjestys (1 = suurin)",
      caption = paste(
        "Nimetään ammattiluokat, jotka ovat kahdeksan kärjessä jommallakummalla akselilla.",
        "Suhdeluvun sija käyttää paketin nimittäjää. Pyöristys ja poistetut solut voivat muuttaa järjestystä.",
        "Täydet nimet ja järjestykset ovat taulukossa.",
        worklife_source_caption(),
        sep = "\n"
      )
    ) +
    theme_worklife()
}

#' Exposure composition of the leading non-COVID occupations.
#'
#' @param exposure Result of \code{exposure_composition()}.
#' @param table Metrics table, used to order occupations.
#' @return ggplot object.
#' @export
plot_exposure <- function(exposure, table) {
  if (nrow(exposure) == 0L) {
    stop("Exposure figure has no rows")
  }
  order_occ <- table$occupation[order(table$rank_ratio_other, table$occupation)]
  order_occ <- order_occ[order_occ %in% exposure$occupation]
  labels <- wrap_fi(table$label_fi[match(order_occ, table$occupation)], 34)
  exposure$label <- factor(
    wrap_fi(exposure$label_fi, 34),
    levels = rev(unique(labels))
  )
  exp_order <- unique(exposure$exposure_fi[order(-exposure$n, exposure$exposure)])
  exposure$exposure_fi <- factor(
    wrap_fi(exposure$exposure_fi, 28),
    levels = wrap_fi(exp_order, 28)
  )
  ggplot2::ggplot(
    exposure,
    ggplot2::aes(x = .data$label, y = .data$n, fill = .data$exposure_fi)
  ) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::scale_x_discrete(expand = ggplot2::expansion(add = c(0.45, 0.45))) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.05))) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 3, byrow = TRUE)) +
    ggplot2::labs(
      title = "Altisteet ilman COVID-19-infektiota",
      subtitle = "Suhdeluvultaan kärjessä olevat ammattiluokat. Puuttuvia soluja ei ole täytetty nollalla.",
      x = NULL,
      y = "Säilytetyt tapaukset, muut diagnoosit",
      fill = "Altisteryhmä",
      caption = worklife_source_caption()
    ) +
    theme_worklife() +
    ggplot2::theme(legend.text = ggplot2::element_text(size = 8))
}

#' Build the four report figures.
#'
#' @param metrics Result of \code{occupation_metrics()}.
#' @param exposure Result of \code{exposure_composition()}.
#' @return Named list of ggplot objects.
#' @export
make_worklife_plots <- function(metrics, exposure) {
  table <- metrics$table
  list(
    counts = plot_count_split(table),
    ratios = plot_period_ratio(table),
    ranks = plot_rank_slope(table),
    exposure = plot_exposure(exposure, table)
  )
}
