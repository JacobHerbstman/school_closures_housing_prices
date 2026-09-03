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

input_file <- sprintf("../input/parcel_sales_%d_%d.csv", start_year, end_year)
condo_file <- sprintf(
  "../input/condo_sale_characteristics_%d_%d.csv",
  start_year,
  end_year
)
output_file <- sprintf(
  "../output/master_home_transactions_%d_%d.csv",
  start_year,
  end_year
)

required_columns <- c(
  "pin", "year", "township_code", "neighborhood_code", "class", "sale_date",
  "is_mydec_date", "sale_price", "sale_document_num", "sale_deed_type",
  "mydec_deed_type", "is_multisale", "num_parcels_sale", "sale_type",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type", "row_id"
)
input_columns <- names(fread(input_file, nrows = 0L))
missing_columns <- setdiff(required_columns, input_columns)
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Parcel-sales input is missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

sales <- fread(
  input_file,
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
  invalid <- !normalized %in% c("true", "false")
  if (any(invalid)) {
    examples <- unique(normalized[invalid])
    stop(
      sprintf(
        "%s contains values other than true or false, including: %s",
        column_name,
        paste(head(examples, 5L), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  normalized == "true"
}

sales[, pin := gsub("[^0-9]", "", trimws(pin))]
sales[nchar(pin) == 13L, pin := paste0("0", pin)]
if (any(nchar(sales$pin) != 14L)) {
  stop("Parcel-sales input contains an invalid full PIN.", call. = FALSE)
}

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

sale_date_text <- trimws(sales$sale_date)
sale_date_parsed <- as.IDate(substr(sale_date_text, 1L, 10L), format = "%Y-%m-%d")
long_date <- is.na(sale_date_parsed) & nzchar(sale_date_text)
sale_date_parsed[long_date] <- as.IDate(sale_date_text[long_date], format = "%B %d, %Y")
sales[, sale_date := sale_date_parsed]

if (anyDuplicated(sales$row_id) > 0L || any(!nzchar(trimws(sales$row_id)))) {
  stop("row_id must be nonempty and unique in the parcel-sales input.", call. = FALSE)
}

cat(sprintf("Source records: %s\n", format(nrow(sales), big.mark = ",")))
sales <- sales[sale_year >= start_year & sale_year <= end_year]
cat(sprintf("Within %d--%d: %s\n", start_year, end_year, format(nrow(sales), big.mark = ",")))

residential_classes <- c(202:212, 234, 278, 295, 299)
single_pin_sales <- sales[
  property_class %in% residential_classes &
    num_parcels_sale == 1L &
    is_multisale == FALSE
]
single_pin_sales[, `:=`(
  sale_price_prorated_nominal = sale_price_nominal,
  unit_proration_share = 1,
  includes_deeded_parking_pin = FALSE,
  parking_pin = NA_character_,
  sale_sample_rule = "single_pin"
)]
cat(sprintf(
  "Single-PIN residential transactions: %s\n",
  format(nrow(single_pin_sales), big.mark = ",")
))

# The unit of observation for the next merge is a source sale row. Condo
# characteristics must be unique by PIN and sale year.
condo_characteristics <- fread(
  condo_file,
  colClasses = list(character = c("pin", "cdu"))
)
required_condo_columns <- c(
  "pin", "year", "card", "property_class", "tieback_proration_rate", "cdu",
  "pin_is_multiland", "pin_num_landlines", "is_parking_space", "is_common_area"
)
missing_condo_columns <- setdiff(required_condo_columns, names(condo_characteristics))
if (length(missing_condo_columns) > 0L) {
  stop(
    sprintf(
      "Condo-characteristics input is missing: %s",
      paste(missing_condo_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}
setnames(condo_characteristics, "year", "sale_year")
if (anyDuplicated(condo_characteristics[, .(pin, sale_year)]) > 0L) {
  stop("Condo characteristics must be unique by PIN and sale year.", call. = FALSE)
}
condo_characteristics[, characteristic_record_found := TRUE]

# A recoverable condo bundle must be represented by exactly two source rows
# under one document number, with two distinct class-299 PINs and one common
# date and price.
two_pin_document_summary <- sales[
  num_parcels_sale == 2L & is_multisale == TRUE & nzchar(trimws(sale_document_num)),
  .(
    source_rows = .N,
    distinct_pins = uniqueN(pin),
    distinct_years = uniqueN(sale_year),
    distinct_dates = uniqueN(sale_date),
    distinct_prices = uniqueN(sale_price_nominal),
    all_condo = all(property_class == 299L)
  ),
  by = sale_document_num
]
two_pin_condo_documents <- two_pin_document_summary[
  source_rows == 2L & distinct_pins == 2L & distinct_years == 1L &
    distinct_dates == 1L & distinct_prices == 1L & all_condo == TRUE,
  sale_document_num
]
two_pin_condo_rows <- sales[
  two_pin_condo_documents,
  on = "sale_document_num",
  nomatch = 0L
]
cat(sprintf(
  "Structurally valid two-PIN condo documents: %s\n",
  format(length(two_pin_condo_documents), big.mark = ",")
))

two_pin_condo_rows <- merge(
  two_pin_condo_rows,
  condo_characteristics,
  by = c("pin", "sale_year"),
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("", "_characteristic")
)
if (nrow(two_pin_condo_rows) != 2L * length(two_pin_condo_documents)) {
  stop("The condo-characteristics join changed the number of candidate source rows.", call. = FALSE)
}

two_pin_validation <- two_pin_condo_rows[, .(
  characteristics_complete = all(!is.na(characteristic_record_found)),
  document_filter_same_sale_within_365 = any(sale_filter_same_sale_within_365),
  document_filter_less_than_10k = any(sale_filter_less_than_10k),
  document_filter_deed_type = any(sale_filter_deed_type),
  parking_count = sum(is_parking_space %in% TRUE),
  unit_count = sum(is_parking_space %in% FALSE),
  garage_count = sum(is_parking_space %in% TRUE & cdu == "GR", na.rm = TRUE),
  no_common_area = all(is_common_area %in% FALSE),
  unit_has_one_landline = sum(
    is_parking_space %in% FALSE &
      pin_is_multiland %in% FALSE &
      pin_num_landlines == 1L,
    na.rm = TRUE
  ) == 1L,
  positive_proration_rates = all(
    is.finite(tieback_proration_rate) & tieback_proration_rate > 0
  ),
  unit_proration_rate = sum(
    tieback_proration_rate[is_parking_space %in% FALSE],
    na.rm = TRUE
  ),
  parking_proration_rate = sum(
    tieback_proration_rate[is_parking_space %in% TRUE],
    na.rm = TRUE
  )
), by = sale_document_num]

two_pin_validation[, verified_condo_parking :=
  characteristics_complete &
    parking_count == 1L &
    unit_count == 1L &
    garage_count == 1L &
    no_common_area &
    unit_has_one_landline &
    positive_proration_rates &
    unit_proration_rate >= 3 * parking_proration_rate]
verified_documents <- two_pin_validation[
  verified_condo_parking == TRUE,
  sale_document_num
]

parking_pins <- two_pin_condo_rows[
  sale_document_num %in% verified_documents & is_parking_space == TRUE,
  .(sale_document_num, parking_pin = pin)
]
recovered_condo_sales <- two_pin_condo_rows[
  sale_document_num %in% verified_documents & is_parking_space == FALSE
]
recovered_condo_sales <- merge(
  recovered_condo_sales,
  two_pin_validation[, .(
    sale_document_num,
    document_filter_same_sale_within_365,
    document_filter_less_than_10k,
    document_filter_deed_type,
    unit_proration_rate,
    parking_proration_rate
  )],
  by = "sale_document_num",
  all.x = TRUE,
  sort = FALSE
)
recovered_condo_sales <- merge(
  recovered_condo_sales,
  parking_pins,
  by = "sale_document_num",
  all.x = TRUE,
  sort = FALSE
)
if (nrow(recovered_condo_sales) != length(verified_documents) ||
    anyDuplicated(recovered_condo_sales$sale_document_num) > 0L) {
  stop("Verified condo-and-parking documents do not resolve to one residential unit.", call. = FALSE)
}

recovered_condo_sales[, `:=`(
  unit_proration_share = unit_proration_rate /
    (unit_proration_rate + parking_proration_rate),
  includes_deeded_parking_pin = TRUE,
  sale_sample_rule = "verified_condo_with_parking",
  sale_filter_same_sale_within_365 = document_filter_same_sale_within_365,
  sale_filter_less_than_10k = document_filter_less_than_10k,
  sale_filter_deed_type = document_filter_deed_type
)]
recovered_condo_sales[, sale_price_prorated_nominal := round(
  sale_price_nominal * unit_proration_share
)]
cat(sprintf(
  "Verified condo-and-parking sales recovered: %s of %s candidates.\n",
  format(nrow(recovered_condo_sales), big.mark = ","),
  format(length(two_pin_condo_documents), big.mark = ",")
))

sales <- rbindlist(
  list(single_pin_sales, recovered_condo_sales),
  use.names = TRUE,
  fill = TRUE
)
if (nrow(sales) == 0L) {
  stop("No residential transactions remain after canonicalization.", call. = FALSE)
}
if (anyNA(sales$sale_date)) {
  stop("A retained sale has an unparseable sale_date.", call. = FALSE)
}
if (any(as.integer(format(sales$sale_date, "%Y")) != sales$sale_year)) {
  stop("A retained sale's sale_date year does not equal its source year.", call. = FALSE)
}
if (any(!is.finite(sales$unit_proration_share)) ||
    any(!sales$unit_proration_share %between% c(0, 1))) {
  stop("A retained sale has an invalid unit-proration share.", call. = FALSE)
}
if (any(
  sales$sale_price_prorated_nominal > sales$sale_price_nominal,
  na.rm = TRUE
)) {
  stop("A prorated sale price exceeds the recorded document price.", call. = FALSE)
}

documented_sales <- sales[nzchar(trimws(sale_document_num))]
if (anyDuplicated(documented_sales[, .(sale_year, sale_document_num)]) > 0L) {
  stop("Master transactions contain a duplicated document-year transaction.", call. = FALSE)
}
if (anyDuplicated(sales$row_id) > 0L) {
  stop("Retained sales are not unique by canonical source row_id.", call. = FALSE)
}

sales[, `:=`(
  sale_month = as.integer(format(sale_date, "%m")),
  sale_quarter = (as.integer(format(sale_date, "%m")) - 1L) %/% 3L + 1L,
  sale_date_precision = fifelse(is_mydec_date, "idor_refined_day", "recording_month")
)]
sales[, property_type := fcase(
  property_class == 299L, "condominium",
  property_class == 212L, "mixed_use_small_residential",
  default = "house_or_small_residential"
)]

unrefined_sales <- sales[is_mydec_date == FALSE]
cat(sprintf(
  "Dates without IDOR refinement: %s; recorded on day one: %s\n",
  format(nrow(unrefined_sales), big.mark = ","),
  format(sum(format(unrefined_sales$sale_date, "%d") == "01"), big.mark = ",")
))

setorder(sales, sale_date, row_id)
output_columns <- c(
  "row_id", "sale_document_num", "pin", "parking_pin", "sale_date", "sale_year",
  "sale_month", "sale_quarter", "is_mydec_date", "sale_date_precision",
  "sale_price_nominal", "sale_price_prorated_nominal", "unit_proration_share",
  "includes_deeded_parking_pin", "sale_sample_rule", "property_class",
  "property_type", "township_code", "neighborhood_code", "sale_deed_type",
  "mydec_deed_type", "sale_type", "is_multisale", "num_parcels_sale",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type"
)

temporary_output <- paste0(output_file, ".tmp")
fwrite(sales[, ..output_columns], temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the completed home-sales file into place.", call. = FALSE)
}
cat(sprintf(
  "Wrote %s master home transactions to %s.\n",
  format(nrow(sales), big.mark = ","),
  output_file
))
