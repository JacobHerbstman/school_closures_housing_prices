# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/logbook/code")

suppressPackageStartupMessages(library(data.table))
coefficients <- fread("../input/coefficients.csv")
summaries <- fread("../input/model_summary.csv")
stopifnot(!anyDuplicated(coefficients[, .(model, term)]), !anyDuplicated(summaries$model))
for (comparison in c("hedonics", "amenities")) {
  model_names <- if (comparison == "hedonics")
    c("did_log", "did_hedonic_log", "did_dollars", "did_hedonic_dollars") else
    c("did_semiannual_hedonic_log", "did_semiannual_amenity_log",
      "did_semiannual_hedonic_dollars", "did_semiannual_amenity_dollars")
  lines <- c("\\begin{tabular}{llrrr}", "\\hline",
    paste("Outcome &", if (comparison == "hedonics") "Hedonics" else "Amenities",
          "& Pooled estimate [95\\% CI] & DiD $p$ & Pre-period $p$ \\\\") , "\\hline")
  for (model_name in model_names) {
    estimate <- coefficients[model == model_name & term == "treated_post"]
    event_summary <- summaries[model == sub("^did_", "event_", model_name)]
    stopifnot(nrow(estimate) == 1L, nrow(event_summary) == 1L)
    values <- unlist(estimate[, .(estimate, conf_low, conf_high)], use.names = FALSE)
    is_log <- endsWith(model_name, "log")
    values <- if (is_log) 100 * (exp(values) - 1) else values / 1000
    added_controls <- if (comparison == "hedonics") grepl("_hedonic_", model_name) else grepl("_amenity_", model_name)
    lines <- c(lines, sprintf("%s & %s & %.1f [%.1f, %.1f] & %.3f & %.3f \\\\",
      if (is_log) "Log (\\%)" else "Dollars (\\$1,000s)", if (added_controls) "Yes" else "No",
      values[1], values[2], values[3], estimate$p_value, event_summary$pretrend_p))
  }
  lines <- c(lines, "\\hline", "\\end{tabular}")
  if (comparison == "hedonics") writeLines(lines, "../output/twfe_table.tex") else
    writeLines(lines, "../output/amenity_table.tex")
}
