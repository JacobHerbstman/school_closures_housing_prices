# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
library(data.table)
source("../../../shared/code/report_data.R")

keys <- list(
  coefficients = c("model", "term"),
  model_summary = c("model"),
  site_year_support = c("school_site_id", "sale_year"),
  raw_price_trends = c("frequency", "weighting", "treated", "period"),
  site_period_support = c("frequency", "school_site_id", "period")
)
report <- capture.output({
  for (dataset in names(keys)) {
    saved <- fread(paste0("../output/", dataset, ".csv"))
    cat("CSV SHA-256:", digest::digest(paste0("../output/", dataset, ".csv"),
        file = TRUE, algo = "sha256"), "\n")
    report_data(saved, dataset, keys[[dataset]])
  }
})
writeLines(trimws(report, which = "right"), "../report/saved_tables.txt")
