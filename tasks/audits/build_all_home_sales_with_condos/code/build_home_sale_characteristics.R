suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript build_home_sale_characteristics.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

transactions <- fread(
  sprintf(
    "../input/master_home_transactions_%d_%d.csv",
    start_year,
    end_year
  ),
  colClasses = list(character = c(
    "row_id", "sale_document_num", "pin", "parking_pin"
  ))
)
residential_improvements <- fread(
  sprintf(
    "../input/residential_improvements_%d_%d.csv",
    start_year,
    end_year
  ),
  colClasses = list(character = c("pin", "tieback_key_pin", "cdu"))
)
condo_characteristics <- fread(
  sprintf(
    "../input/condo_sale_characteristics_%d_%d.csv",
    start_year,
    end_year
  ),
  colClasses = list(character = c(
    "pin", "pin10", "tieback_key_pin", "cdu"
  ))
)

required_transaction_columns <- c("row_id", "pin", "sale_year", "property_type")
missing_transaction_columns <- setdiff(required_transaction_columns, names(transactions))
if (length(missing_transaction_columns) > 0L) {
  stop(
    sprintf(
      "Master transactions are missing: %s",
      paste(missing_transaction_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}
if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Master transactions must be nonempty and unique by row_id.", call. = FALSE)
}
if (anyDuplicated(residential_improvements[, .(pin, year, card)]) > 0L) {
  stop("Residential improvements must be unique by PIN, year, and card.", call. = FALSE)
}
if (anyDuplicated(condo_characteristics[, .(pin, year)]) > 0L) {
  stop("Condo characteristics must be unique by PIN and year.", call. = FALSE)
}

transactions[, source_order := .I]

# Residential characteristics have one row per physical improvement card. Keep
# the card count for every non-condo PIN-year, but attach characteristics only
# when the PIN-year has exactly one card.
residential_card_counts <- residential_improvements[, .(
  res_improvement_card_count = .N
), by = .(pin, year)]
single_card_keys <- residential_card_counts[
  res_improvement_card_count == 1L,
  .(pin, year)
]
single_card_characteristics <- residential_improvements[
  single_card_keys,
  on = .(pin, year),
  nomatch = 0L
]
residential_columns <- setdiff(names(single_card_characteristics), c("pin", "year"))
setnames(
  single_card_characteristics,
  residential_columns,
  paste0("res_", residential_columns)
)

condo_characteristics[, record_found := TRUE]
condo_columns <- setdiff(names(condo_characteristics), c("pin", "year"))
setnames(
  condo_characteristics,
  condo_columns,
  fifelse(
    startsWith(condo_columns, "condo_"),
    condo_columns,
    paste0("condo_", condo_columns)
  )
)

# Each join is many transactions to one PIN-year characteristic record.
characterized_sales <- merge(
  transactions,
  residential_card_counts,
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
characterized_sales <- merge(
  characterized_sales,
  condo_characteristics,
  by.x = c("pin", "sale_year"),
  by.y = c("pin", "year"),
  all.x = TRUE,
  sort = FALSE
)
setorder(characterized_sales, source_order)
characterized_sales[, condo_building_units :=
  condo_building_pins - condo_building_non_units]

if (nrow(characterized_sales) != nrow(transactions) ||
    anyDuplicated(characterized_sales$row_id) > 0L ||
    !identical(characterized_sales$row_id, transactions$row_id)) {
  stop("The characteristic joins changed the master transaction rows or order.", call. = FALSE)
}
if (any(characterized_sales$condo_building_units < 0, na.rm = TRUE)) {
  stop("A condo building has more non-livable parcels than total parcels.", call. = FALSE)
}

is_condo <- characterized_sales$property_type == "condominium"
characterized_sales[, `:=`(
  res_characteristics_match = fifelse(
    is_condo,
    NA,
    !is.na(res_improvement_card_count)
  ),
  res_single_card = fifelse(
    is_condo,
    NA,
    !is.na(res_improvement_card_count) & res_improvement_card_count == 1L
  ),
  condo_characteristics_match = fifelse(
    is_condo,
    condo_record_found %in% TRUE,
    NA
  ),
  condo_is_livable = fifelse(
    is_condo,
    condo_record_found %in% TRUE &
      condo_is_parking_space %in% FALSE &
      condo_is_common_area %in% FALSE,
    NA
  ),
  condo_single_landline = fifelse(
    is_condo,
    condo_record_found %in% TRUE &
      condo_pin_is_multiland %in% FALSE &
      condo_pin_num_landlines == 1L,
    NA
  )
)]
characterized_sales[, baseline_hedonic_eligible := fifelse(
  property_type == "condominium",
  condo_is_livable %in% TRUE & condo_single_landline %in% TRUE,
  res_single_card %in% TRUE
)]
characterized_sales[, c("source_order", "condo_record_found") := NULL]

noncondo_sales <- characterized_sales[property_type != "condominium"]
condo_sales <- characterized_sales[property_type == "condominium"]
residential_match_rate <- mean(noncondo_sales$res_characteristics_match)
condo_match_rate <- mean(condo_sales$condo_characteristics_match)
if (!is.finite(residential_match_rate) || residential_match_rate < 0.999) {
  stop(
    sprintf(
      "Only %.3f percent of non-condo transactions match an improvement PIN-year.",
      100 * residential_match_rate
    ),
    call. = FALSE
  )
}
if (!is.finite(condo_match_rate) || condo_match_rate < 0.99) {
  stop(
    sprintf(
      "Only %.3f percent of condo transactions match a condo PIN-year.",
      100 * condo_match_rate
    ),
    call. = FALSE
  )
}
if (any(
  condo_sales$condo_characteristics_match %in% TRUE &
    condo_sales$condo_property_class != 299L,
  na.rm = TRUE
)) {
  stop("A matched condo transaction has a non-condo characteristic class.", call. = FALSE)
}

cat(sprintf(
  "Residential characteristics match %.4f percent of non-condo transactions.\n",
  100 * residential_match_rate
))
cat(sprintf(
  "%s non-condo transactions have one improvement card; %s have multiple cards.\n",
  format(noncondo_sales[res_single_card == TRUE, .N], big.mark = ","),
  format(noncondo_sales[res_improvement_card_count > 1L, .N], big.mark = ",")
))
cat(sprintf(
  "Condo characteristics match %.4f percent of condo transactions; %s matched PINs are non-livable and %s livable PINs span multiple landlines.\n",
  100 * condo_match_rate,
  format(condo_sales[condo_characteristics_match == TRUE & condo_is_livable == FALSE, .N], big.mark = ","),
  format(condo_sales[condo_is_livable == TRUE & condo_single_landline == FALSE, .N], big.mark = ",")
))

setorder(characterized_sales, sale_date, row_id)
output_file <- sprintf(
  "../output/home_sales_with_characteristics_%d_%d.csv",
  start_year,
  end_year
)
temporary_output <- paste0(output_file, ".tmp")
fwrite(characterized_sales, temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the characterized transaction file into place.", call. = FALSE)
}
cat(sprintf(
  "Wrote %s characterized master transactions to %s.\n",
  format(nrow(characterized_sales), big.mark = ","),
  output_file
))
