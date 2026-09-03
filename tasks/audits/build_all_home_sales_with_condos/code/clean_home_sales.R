suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript clean_home_sales.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

transactions <- fread(
  sprintf(
    "../input/home_sales_with_characteristics_%d_%d.csv",
    start_year,
    end_year
  ),
  colClasses = list(character = c(
    "row_id", "sale_document_num", "pin", "parking_pin"
  ))
)
if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Master transactions must contain records uniquely keyed by row_id.", call. = FALSE)
}

required_columns <- c(
  "sale_year", "sale_price_nominal", "sale_type",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type", "property_class", "property_type",
  "sale_sample_rule", "condo_is_livable", "baseline_hedonic_eligible"
)
missing_columns <- setdiff(required_columns, names(transactions))
if (length(missing_columns) > 0L) {
  stop(
    sprintf(
      "Master transactions are missing: %s",
      paste(missing_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}
if (!identical(sort(unique(transactions$sale_year)), start_year:end_year)) {
  stop("Master transactions do not span the requested years.", call. = FALSE)
}

cat(sprintf(
  "Characterized master transactions: %s\n",
  format(nrow(transactions), big.mark = ",")
))

home_sales <- transactions[
  sale_filter_same_sale_within_365 == FALSE &
    sale_filter_less_than_10k == FALSE &
    sale_filter_deed_type == FALSE
]
cat(sprintf(
  "Passing Cook County sale-quality flags: %s\n",
  format(nrow(home_sales), big.mark = ",")
))

home_sales <- home_sales[
  is.finite(sale_price_nominal) &
    sale_price_nominal > 10000 &
    !is.na(sale_type) &
    sale_type != "LAND"
]
cat(sprintf(
  "Market sales above $10,000: %s\n",
  format(nrow(home_sales), big.mark = ",")
))

# Cook County excludes parking, storage, and common-area condo PINs from its
# condo model. Unmatched condo PIN-years cannot be verified as livable.
nonlivable_or_unmatched_condos <- home_sales[
  property_type == "condominium" & condo_is_livable != TRUE
]
home_sales <- home_sales[
  property_type != "condominium" | condo_is_livable == TRUE
]
cat(sprintf(
  "Excluded %s non-livable or unmatched condo PIN sales.\n",
  format(nrow(nonlivable_or_unmatched_condos), big.mark = ",")
))

if (nrow(home_sales) == 0L) {
  stop("No home sales remain after applying the market-sale restrictions.", call. = FALSE)
}
if (anyDuplicated(home_sales$row_id) > 0L) {
  stop("Clean home sales are not unique by canonical source row_id.", call. = FALSE)
}
documented_sales <- home_sales[nzchar(trimws(sale_document_num))]
if (anyDuplicated(documented_sales[, .(sale_year, sale_document_num)]) > 0L) {
  stop("Clean home sales contain a duplicated document-year transaction.", call. = FALSE)
}
if (any(!home_sales$property_class %in% c(202:212, 234, 278, 295, 299))) {
  stop("Clean home sales contain an unexpected property class.", call. = FALSE)
}
if (any(home_sales$property_type == "condominium" & home_sales$condo_is_livable != TRUE)) {
  stop("Clean home sales contain a non-livable or unverified condo PIN.", call. = FALSE)
}

setorder(home_sales, sale_date, row_id)
temporary_output <- sprintf(
  "../output/home_sales_%d_%d.csv.tmp",
  start_year,
  end_year
)
output_file <- sprintf(
  "../output/home_sales_%d_%d.csv",
  start_year,
  end_year
)
fwrite(home_sales, temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the completed home-sales file into place.", call. = FALSE)
}
cat(sprintf(
  "Wrote %s market-sale transactions to %s.\n",
  format(nrow(home_sales), big.mark = ","),
  output_file
))
