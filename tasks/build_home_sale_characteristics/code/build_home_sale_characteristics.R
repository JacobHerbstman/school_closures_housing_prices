# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/build_home_sale_characteristics/code")
suppressPackageStartupMessages(library(data.table))

transactions <- fread(
  "../input/master_home_transactions_2006_2025.csv",
  colClasses = list(character = c("row_id", "sale_document_num", "pin"))
)
improvements <- fread(
  "../input/residential_improvements_2006_2025.csv",
  colClasses = list(character = c("pin", "tieback_key_pin", "cdu"))
)

if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Master transactions must be nonempty and unique by row_id.", call. = FALSE)
}
if (anyDuplicated(improvements[, .(pin, year, card)]) > 0L) {
  stop("Residential improvements must be unique by PIN, year, and card.", call. = FALSE)
}

transactions[, source_order := .I]
card_counts <- improvements[, .(improvement_card_count = .N), by = .(pin, year)]
single_card_characteristics <- improvements[
  card_counts[improvement_card_count == 1L, .(pin, year)],
  on = .(pin, year),
  nomatch = 0L
]
characteristic_columns <- setdiff(names(single_card_characteristics), c("pin", "year"))
setnames(
  single_card_characteristics,
  characteristic_columns,
  paste0("res_", characteristic_columns)
)

# Both joins are many transactions to one PIN-year record.
characterized_sales <- merge(
  transactions,
  card_counts,
  by.x = c("pin", "sale_year"),
  by.y = c("pin", "year"),
  all.x = TRUE,
  sort = FALSE
)
characterized_sales <- merge(
  characterized_sales,
  single_card_characteristics,
  by.x = c("pin", "sale_year"),
  by.y = c("pin", "year"),
  all.x = TRUE,
  sort = FALSE
)
setorder(characterized_sales, source_order)

if (nrow(characterized_sales) != nrow(transactions) ||
    anyDuplicated(characterized_sales$row_id) > 0L ||
    !identical(characterized_sales$row_id, transactions$row_id)) {
  stop("The improvement joins changed the master transaction rows or order.", call. = FALSE)
}

characterized_sales[, `:=`(
  improvement_characteristics_match = !is.na(improvement_card_count),
  single_improvement_card = !is.na(improvement_card_count) & improvement_card_count == 1L
)]
characterized_sales[, source_order := NULL]

match_rate <- mean(characterized_sales$improvement_characteristics_match)
if (!is.finite(match_rate) || match_rate < 0.999) {
  stop(
    sprintf("Only %.3f percent of transactions match an improvement PIN-year.", 100 * match_rate),
    call. = FALSE
  )
}
cat(sprintf(
  "Improvement characteristics match %.4f percent of transactions.\n",
  100 * match_rate
))
cat(sprintf(
  "%s transactions have one improvement card; %s have multiple cards.\n",
  format(characterized_sales[single_improvement_card == TRUE, .N], big.mark = ","),
  format(characterized_sales[improvement_card_count > 1L, .N], big.mark = ",")
))

setorder(characterized_sales, sale_date, row_id)
output_file <- "../output/home_sales_with_characteristics_2006_2025.csv"
fwrite(characterized_sales, output_file)
cat(sprintf("Wrote %s characterized transactions to %s.\n", nrow(characterized_sales), output_file))
