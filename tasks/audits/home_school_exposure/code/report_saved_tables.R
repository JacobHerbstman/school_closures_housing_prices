# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_school_exposure/code")
library(data.table)
source("../../../shared/code/report_data.R")

keys <- list(
  exposure_summary = c("focal_exposure_025"),
  treatment_control_summary = c("sample_definition", "summary_period", "exposure_group"),
  annual_real_price_summary = c("sale_year", "exposure_group"),
  annual_residualized_real_price_summary = c("sale_year", "exposure_group"),
  subannual_residualized_real_price_summary = c("frequency", "period", "exposure_group"),
  school_site_support = c("school_location_id"),
  treated_control_overlap_pairs = c("nearest_treated_site_id", "nearest_control_site_id"),
  competing_exposure = c("focal_exposure_025", "competing_exposure"),
  radius_sensitivity = c("radius_miles")
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
