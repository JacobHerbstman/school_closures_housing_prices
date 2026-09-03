suppressPackageStartupMessages(library(data.table))

transactions <- fread("../input/master_home_transactions_2006_2025.csv",
                      colClasses = list(character = c("row_id", "pin", "sale_document_num")))
coordinates <- fread("../input/historical_sale_coordinates_2006_2025.csv",
                     colClasses = list(character = "pin"))
# Many transactions to one exact historical PIN-year. Retain the whole master,
# including any blank coordinates, independently of all analysis restrictions.
stopifnot(nrow(transactions) > 0L, !anyDuplicated(transactions$row_id),
          !anyDuplicated(coordinates[, .(pin, sale_year)]))
geocoded <- coordinates[transactions, on = .(pin, sale_year)]
stopifnot(nrow(geocoded) == nrow(transactions), identical(geocoded$row_id, transactions$row_id),
          !anyNA(geocoded$has_historical_coordinates),
          mean(geocoded$has_historical_coordinates) >= 0.999)
geocoded[, coordinate_source := "historical_exact_pin_year"]
setcolorder(geocoded, c(names(transactions), setdiff(names(geocoded), names(transactions))))
fwrite(geocoded, "../output/geocoded_master_home_transactions_2006_2025.csv", na = "NA")
cat(sprintf("Preserved %s master transactions; %s have complete historical coordinates.\n",
            nrow(geocoded), sum(geocoded$has_historical_coordinates)))
