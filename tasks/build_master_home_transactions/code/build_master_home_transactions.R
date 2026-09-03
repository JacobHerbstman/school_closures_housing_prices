suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript build_master_home_transactions.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

required_columns <- c(
  "pin", "year", "township_code", "neighborhood_code", "class", "sale_date",
  "is_mydec_date", "sale_price", "sale_document_num", "sale_deed_type",
  "mydec_deed_type", "is_multisale", "num_parcels_sale", "sale_type",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type", "row_id"
)
input_columns <- names(fread(
  sprintf("../input/parcel_sales_%d_%d.csv", start_year, end_year),
  nrows = 0L
))
missing_columns <- setdiff(required_columns, input_columns)
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Parcel-sales input is missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

sales <- fread(
  sprintf("../input/parcel_sales_%d_%d.csv", start_year, end_year),
  select = required_columns,
  na.strings = NULL,
  colClasses = list(character = c(
    "pin", "sale_date", "sale_price", "sale_document_num", "row_id"
  ))
)
if (nrow(sales) == 0L) {
  stop("Parcel-sales input contains no records.", call. = FALSE)
}

parse_boolean <- function(values, column_name) {
  normalized <- tolower(trimws(as.character(values)))
  if (any(!normalized %in% c("true", "false"))) {
    stop(sprintf("%s contains a value other than true or false.", column_name), call. = FALSE)
  }
  normalized == "true"
}

sales[, pin := gsub("[^0-9]", "", trimws(pin))]
sales[nchar(pin) == 13L, pin := paste0("0", pin)]
sales[, `:=`(
  sale_year = suppressWarnings(as.integer(year)),
  property_class = suppressWarnings(as.integer(class)),
  sale_price_nominal = suppressWarnings(as.numeric(gsub("[$,]", "", sale_price))),
  num_parcels_sale = suppressWarnings(as.integer(num_parcels_sale)),
  is_mydec_date = parse_boolean(is_mydec_date, "is_mydec_date"),
  is_multisale = parse_boolean(is_multisale, "is_multisale"),
  sale_filter_same_sale_within_365 = parse_boolean(
    sale_filter_same_sale_within_365,
    "sale_filter_same_sale_within_365"
  ),
  sale_filter_less_than_10k = parse_boolean(
    sale_filter_less_than_10k,
    "sale_filter_less_than_10k"
  ),
  sale_filter_deed_type = parse_boolean(sale_filter_deed_type, "sale_filter_deed_type")
)]
if (any(nchar(sales$pin) != 14L) || anyNA(sales$year)) {
  stop("Parcel-sales input contains an invalid full PIN or year.", call. = FALSE)
}
if (anyDuplicated(sales$row_id) > 0L || any(!nzchar(trimws(sales$row_id)))) {
  stop("row_id must be nonempty and unique in the parcel-sales input.", call. = FALSE)
}

sale_date_text <- trimws(sales$sale_date)
sale_date_parsed <- as.IDate(substr(sale_date_text, 1L, 10L), format = "%Y-%m-%d")
long_date <- is.na(sale_date_parsed) & nzchar(sale_date_text)
sale_date_parsed[long_date] <- as.IDate(sale_date_text[long_date], format = "%B %d, %Y")
sales[, sale_date := sale_date_parsed]

cat(sprintf("Source records: %s\n", format(nrow(sales), big.mark = ",")))
sales <- sales[
  sale_year %between% c(start_year, end_year) &
    property_class %in% c(202:212, 234, 278, 295) &
    num_parcels_sale == 1L &
    is_multisale == FALSE
]
cat(sprintf(
  "Single-PIN non-condominium residential transactions: %s\n",
  format(nrow(sales), big.mark = ",")
))

if (nrow(sales) == 0L || anyNA(sales$sale_date)) {
  stop("No valid residential transactions remain after canonicalization.", call. = FALSE)
}
if (any(as.integer(format(sales$sale_date, "%Y")) != sales$sale_year)) {
  stop("A retained sale's date year does not equal its source year.", call. = FALSE)
}
documented_sales <- sales[nzchar(trimws(sale_document_num))]
if (anyDuplicated(documented_sales[, .(sale_year, sale_document_num)]) > 0L) {
  stop("Master transactions contain a duplicated document-year transaction.", call. = FALSE)
}

sales[, `:=`(
  sale_month = as.integer(format(sale_date, "%m")),
  sale_quarter = (as.integer(format(sale_date, "%m")) - 1L) %/% 3L + 1L,
  sale_date_precision = fifelse(is_mydec_date, "idor_refined_day", "recording_month"),
  property_type = fifelse(
    property_class == 212L,
    "mixed_use_small_residential",
    "house_or_small_residential"
  )
)]

unrefined_sales <- sales[is_mydec_date == FALSE]
cat(sprintf(
  "Dates without IDOR refinement: %s; recorded on day one: %s\n",
  format(nrow(unrefined_sales), big.mark = ","),
  format(sum(format(unrefined_sales$sale_date, "%d") == "01"), big.mark = ",")
))

setorder(sales, sale_date, row_id)
output_columns <- c(
  "row_id", "sale_document_num", "pin", "sale_date", "sale_year",
  "sale_month", "sale_quarter", "is_mydec_date", "sale_date_precision",
  "sale_price_nominal", "property_class", "property_type", "township_code",
  "neighborhood_code", "sale_deed_type", "mydec_deed_type", "sale_type",
  "is_multisale", "num_parcels_sale", "sale_filter_same_sale_within_365",
  "sale_filter_less_than_10k", "sale_filter_deed_type"
)
output_file <- sprintf(
  "../output/master_home_transactions_%d_%d.csv",
  start_year,
  end_year
)
fwrite(sales[, ..output_columns], output_file)
cat(sprintf("Wrote %s master transactions to %s.\n", nrow(sales), output_file))
