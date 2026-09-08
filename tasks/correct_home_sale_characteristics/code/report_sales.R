# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/correct_home_sale_characteristics/code")
library(data.table)
source("../../shared/code/report_data.R")
sales <- fread("../output/corrected_home_sale_characteristics_2006_2025.csv",
               colClasses = c(row_id = "character", pin = "character", sale_document_num = "character"))
report <- capture.output({
  cat("CSV SHA-256:", digest::digest("../output/corrected_home_sale_characteristics_2006_2025.csv",
      file = TRUE, algo = "sha256"), "\n")
  report_data(sales, "corrected_home_sale_characteristics_2006_2025", "row_id")
})
writeLines(trimws(report, which = "right"), "../report/corrected_home_sale_characteristics_2006_2025.txt")
