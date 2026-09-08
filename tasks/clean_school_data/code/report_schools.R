# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/clean_school_data/code")
library(data.table)
source("../../shared/code/report_data.R")
schools <- fread("../output/Elementary_Closure_SY1213_Chicago_Clean.csv")
report <- capture.output({
  cat("SHA-256:",digest::digest("../output/Elementary_Closure_SY1213_Chicago_Clean.csv",file=TRUE,algo="sha256"),"\n")
  report_data(schools,"Clean candidate-school roster","school_id")
})
writeLines(trimws(report, which = "right"), "../report/schools.txt")
