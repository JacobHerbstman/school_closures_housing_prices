# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/logbook/code")
# RStudio: set design <- "common" (or "varying"), then run below the argument block.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
design <- args[1]
stopifnot(design %in% c("varying", "common"))
library(data.table)
if (design == "common") {
  coefficients <- fread("../input/ring_common_coefficients.csv")
  samples <- fread("../input/ring_common_sample_summary.csv")
} else {
  coefficients <- fread("../input/ring_coefficients.csv")
  samples <- fread("../input/ring_sample_summary.csv")
}
rings <- c("within_0125", "annulus_0125_025", "annulus_025_05")
labels <- c("0--0.125", "0.125--0.25", "0.25--0.5")
lines <- character(3)
for (index in 1:3) {
  data <- coefficients[ring == rings[index] & estimator == "did" & weighting == "equal_site_year" & specification == "site_hedonics"]
  counts <- samples[ring == rings[index]][order(treated)]
  dollars <- unlist(data[outcome == "dollars", .(estimate, conf_low, conf_high)]) / 1000
  logs <- 100 * (exp(unlist(data[outcome == "log", .(estimate, conf_low, conf_high)])) - 1)
  lines[index] <- sprintf("%s & %d / %d & %.1f [%.1f, %.1f] & %.1f [%.1f, %.1f] \\\\", labels[index],
    counts[treated == 1, sites], counts[treated == 0, sites], dollars[1], dollars[2], dollars[3], logs[1], logs[2], logs[3])
}
writeLines(c("\\begin{tabular}{lrrr}", "\\hline", "Miles & Sites (T/C) & Dollar DiD (\\$1,000s) & Log DiD (percent) \\\\",
  "\\hline", lines, "\\hline", "\\end{tabular}"), if (design == "common") "../output/common_ring_table.tex" else "../output/ring_table.tex")
