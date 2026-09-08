# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_rings/code")
library(data.table)
source("../../../shared/code/report_data.R")

keys <- list(
  coefficients = c("ring", "weighting", "specification", "outcome", "estimator", "term"),
  model_summary = c("ring", "weighting", "specification", "outcome", "estimator"),
  site_year_support = c("ring", "school_site_id", "sale_year"),
  raw_trends = c("ring", "weighting", "treated", "sale_year"),
  sample_summary = c("ring", "treated"),
  common_coefficients = c("ring", "weighting", "specification", "outcome", "estimator", "term"),
  common_model_summary = c("ring", "weighting", "specification", "outcome", "estimator"),
  common_site_year_support = c("ring", "school_site_id", "sale_year"),
  common_raw_trends = c("ring", "weighting", "treated", "sale_year"),
  common_sample_summary = c("ring", "treated"),
  common_support = c("school_site_id", "ring", "sale_year")
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
