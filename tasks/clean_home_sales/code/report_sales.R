# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/clean_home_sales/code")
# start_year <- 2008L
# end_year <- 2018L
library(data.table)
source("../../shared/code/report_data.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
start_year <- as.integer(args[1])
end_year <- as.integer(args[2])
stopifnot(!is.na(start_year), !is.na(end_year), start_year <= end_year)
sales <- fread(sprintf("../output/home_sales_%d_%d.csv", start_year, end_year),
               colClasses = c(row_id = "character", pin = "character", sale_document_num = "character"))
report <- capture.output({
  cat("CSV SHA-256:", digest::digest(sprintf("../output/home_sales_%d_%d.csv", start_year, end_year),
      file = TRUE, algo = "sha256"), "\n")
  report_data(sales, sprintf("home_sales_%d_%d", start_year, end_year), "row_id")
})
writeLines(trimws(report, which = "right"), sprintf("../report/home_sales_%d_%d.txt", start_year, end_year))
