# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
library(data.table)
source("../../../shared/code/report_data.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
dataset <- args[1]
# dataset <- "annual_prices"
keys <- list(
  analysis_sample = "row_id",
  annual_prices = c("treated", "sale_year"),
  tail_contributions = c("treated", "sale_year", "tail_fraction"),
  expensive_sales = "row_id",
  property_composition = c("treated", "sale_year", "property_type"),
  site_omission_coefficients = c("model", "omitted_site_id", "term"),
  site_omission_models = c("model", "omitted_site_id"),
  price_band_periods = c("treated", "period", "price_band"),
  upper_tail_sites = c("treated", "period", "school_site_id"),
  initial_price_sites = "school_site_id",
  initial_price_coefficients = c("model", "initial_price_adjusted", "term"),
  initial_price_models = c("model", "initial_price_adjusted")
)
stopifnot(dataset %in% names(keys))
columns <- names(fread(paste0("../output/", dataset, ".csv"), nrows = 0))
d <- fread(paste0("../output/", dataset, ".csv"),
           colClasses = list(character = intersect(c("row_id", "pin"), columns)))
report <- capture.output({
  cat("SHA-256:", digest::digest(paste0("../output/", dataset, ".csv"),
      algo = "sha256", file = TRUE), "\n")
  report_data(d, dataset, keys[[dataset]])
})
writeLines(trimws(report, which = "right"), paste0("../report/", dataset, ".txt"))
