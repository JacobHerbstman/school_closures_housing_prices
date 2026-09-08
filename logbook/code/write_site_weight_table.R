# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/logbook/code")
library(data.table)
coefficients <- fread("../input/coefficients.csv")
base_models <- c("did_hedonic_dollars", "did_hedonic_log", "did_semiannual_hedonic_dollars",
                 "did_semiannual_hedonic_log", "did_semiannual_amenity_dollars", "did_semiannual_amenity_log")
labels <- rep(c("Annual, hedonics", "Half-year, hedonics", "Half-year, amenities"), each = 2)
lines <- character(length(base_models))
for (i in seq_along(base_models)) {
  names <- c(base_models[i], sub("^did_", "did_site_", base_models[i]))
  rows <- coefficients[match(names, model)]
  stopifnot(identical(rows$model, names))
  values <- as.matrix(rows[, .(estimate, conf_low, conf_high)])
  values <- if (endsWith(base_models[i], "log")) 100 * (exp(values) - 1) else values / 1000
  cells <- sprintf("%.1f [%.1f, %.1f]", values[, 1], values[, 2], values[, 3])
  lines[i] <- paste(labels[i], if (endsWith(base_models[i], "log")) "Percent" else "\\$1,000s",
                    cells[1], cells[2], sep = " & ")
}
writeLines(c("\\begin{tabular}{llrr}", "\\hline",
 "Specification & Outcome & Equal transactions & Equal site-periods \\\\", "\\hline",
 paste0(lines, " \\\\"), "\\hline", "\\end{tabular}"), "../output/site_weight_table.tex")
