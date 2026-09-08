# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_baseline_demographics/code")
library(data.table)
source("../../../shared/code/report_data.R")

keys <- list(
  demographic_balance = c("geography", "weighting", "variable")
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
