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
  "../input/corrected_home_sale_characteristics_2006_2025.csv",
  colClasses = list(character = c(
    "row_id", "sale_document_num", "pin", "res_char_apts"
  ))
)
if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Characterized transactions must be nonempty and unique by row_id.", call. = FALSE)
}

required_columns <- c(
  "sale_year", "sale_month", "sale_price_nominal", "sale_type",
  "analysis_class", "property_type_conflict",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type", "single_improvement_card", "res_char_yrblt",
  "res_char_bldg_sf", "res_char_land_sf", "res_char_beds",
  "res_char_rooms", "res_char_fbath", "res_char_type_resd",
  "res_char_cnst_qlty", "res_char_repair_cnd", "res_char_apts"
)
missing_columns <- setdiff(required_columns, names(transactions))
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Characterized transactions are missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

home_sales <- transactions[sale_year %between% c(start_year, end_year)]
cat(sprintf("Transactions in %d--%d: %s\n", start_year, end_year, format(nrow(home_sales), big.mark = ",")))

home_sales <- home_sales[
  sale_filter_same_sale_within_365 == FALSE &
    sale_filter_less_than_10k == FALSE &
    sale_filter_deed_type == FALSE
]
cat(sprintf("Passing Cook County sale-quality flags: %s\n", format(nrow(home_sales), big.mark = ",")))

home_sales <- home_sales[
  is.finite(sale_price_nominal) & sale_price_nominal > 10000 &
    !is.na(sale_type) & sale_type != "LAND"
]
cat(sprintf("Non-land market sales above $10,000: %s\n", format(nrow(home_sales), big.mark = ",")))

home_sales <- home_sales[
  single_improvement_card == TRUE & analysis_class %in% c(202:211, 234, 278, 295)
]
cat(sprintf(
  "Single-card non-mixed-use residential sales: %s\n",
  format(nrow(home_sales), big.mark = ",")
))

complete_core_hedonics <-
  is.finite(home_sales$res_char_yrblt) &
  is.finite(home_sales$res_char_bldg_sf) & home_sales$res_char_bldg_sf > 0 &
  is.finite(home_sales$res_char_land_sf) & home_sales$res_char_land_sf > 0 &
  is.finite(home_sales$res_char_beds) &
  is.finite(home_sales$res_char_rooms) &
  is.finite(home_sales$res_char_fbath) &
  !is.na(home_sales$res_char_type_resd) & nzchar(trimws(home_sales$res_char_type_resd)) &
  !is.na(home_sales$res_char_cnst_qlty) & nzchar(trimws(home_sales$res_char_cnst_qlty)) &
  !is.na(home_sales$res_char_repair_cnd) & nzchar(trimws(home_sales$res_char_repair_cnd))
home_sales <- home_sales[complete_core_hedonics]

home_sales[, apartment_count := fcase(
  res_char_apts == "Two", 2L,
  res_char_apts == "Three", 3L,
  res_char_apts == "Four", 4L,
  res_char_apts == "Five", 5L,
  res_char_apts == "Six", 6L,
  default = NA_integer_
)]
home_sales <- home_sales[
  analysis_class != 211L | !is.na(apartment_count)
]
cat(sprintf(
  "Complete core hedonics and class-211 apartment counts: %s\n",
  format(nrow(home_sales), big.mark = ",")
))

home_sales[, price_per_building_sqft := sale_price_nominal / res_char_bldg_sf]
confirmed_characteristic_errors <- home_sales$res_char_rooms < home_sales$res_char_beds
confirmed_price_errors <- home_sales$price_per_building_sqft > 5000
cat(sprintf(
  "Excluding %s internally inconsistent hedonic records and %s implausible prices.\n",
  format(sum(confirmed_characteristic_errors), big.mark = ","),
  format(sum(confirmed_price_errors), big.mark = ",")
))
home_sales <- home_sales[
  !confirmed_characteristic_errors & !confirmed_price_errors
]

if (nrow(home_sales) == 0L || anyDuplicated(home_sales$row_id) > 0L) {
  stop("Clean home sales must be nonempty and unique by row_id.", call. = FALSE)
}
if (any(!home_sales$analysis_class %in% c(202:211, 234, 278, 295)) ||
    any(home_sales$property_type_conflict)) {
  stop("Clean home sales contain an excluded or unexpected property class.", call. = FALSE)
}
if (any(home_sales$res_char_yrblt > home_sales$sale_year) ||
    any(home_sales$res_char_beds < 0) ||
    any(home_sales$res_char_rooms < home_sales$res_char_beds) ||
    any(home_sales$res_char_fbath < 0)) {
  stop("Clean home sales contain an impossible core characteristic.", call. = FALSE)
}
if (any(!is.finite(home_sales$price_per_building_sqft)) ||
    any(home_sales$price_per_building_sqft <= 0 | home_sales$price_per_building_sqft > 5000)) {
  stop("Clean home sales contain an invalid price per square foot.", call. = FALSE)
}
documented_sales <- home_sales[nzchar(trimws(sale_document_num))]
if (anyDuplicated(documented_sales[, .(sale_year, sale_document_num)]) > 0L) {
  stop("Clean home sales contain a duplicated document-year transaction.", call. = FALSE)
}

# Trim the upper price-per-square-foot tail after the existing sample screens.
# Each sale year uses one citywide nominal cutoff, independent of school exposure.
# Values equal to the cutoff remain; no lower-tail trimming or winsorization.
home_sales[, price_per_sqft_p999 := quantile(price_per_building_sqft, 0.999, type = 7),
           by = sale_year]
cat("Within-year 99.9th-percentile price-per-square-foot trim:\n")
print(home_sales[, .(
  cutoff_nominal = first(price_per_sqft_p999),
  sales_before = .N,
  sales_removed = sum(price_per_building_sqft > price_per_sqft_p999)
), by = sale_year][order(sale_year)])
home_sales <- home_sales[price_per_building_sqft <= price_per_sqft_p999]
home_sales[, price_per_sqft_p999 := NULL]

cpi <- fread("../input/chicago_cpi_all_items.csv")
if (!all(c("observation_date", "chicago_cpi_all_items") %in% names(cpi))) {
  stop("Chicago CPI input is missing required columns.", call. = FALSE)
}
cpi[, `:=`(
  sale_year = as.integer(substr(observation_date, 1L, 4L)),
  sale_month = as.integer(substr(observation_date, 6L, 7L))
)]
base_cpi_values <- cpi[sale_year == 2022L, chicago_cpi_all_items]
base_cpi <- mean(base_cpi_values)
cpi <- cpi[
  sale_year %between% c(start_year, end_year),
  .(sale_year, sale_month, chicago_cpi_all_items)
]

if (nrow(cpi) != 12L * (end_year - start_year + 1L) ||
    anyDuplicated(cpi[, .(sale_year, sale_month)]) > 0L ||
    any(!is.finite(cpi$chicago_cpi_all_items)) ||
    length(base_cpi_values) != 12L ||
    !is.finite(base_cpi) || base_cpi <= 0) {
  stop("Chicago CPI does not cover the requested sample and base year.", call. = FALSE)
}

home_sales[cpi, on = .(sale_year, sale_month), `:=`(
  sale_price_cpi_chicago_all_items = i.chicago_cpi_all_items,
  sale_price_deflator_to_2022 = base_cpi / i.chicago_cpi_all_items
)]
home_sales[, `:=`(
  sale_price_real_2022 = sale_price_nominal * sale_price_deflator_to_2022,
  price_per_building_sqft_real_2022 =
    sale_price_nominal * sale_price_deflator_to_2022 / res_char_bldg_sf
)]

if (any(!is.finite(home_sales$sale_price_real_2022)) ||
    any(home_sales$sale_price_real_2022 <= 0) ||
    any(!is.finite(home_sales$price_per_building_sqft_real_2022)) ||
    any(home_sales$price_per_building_sqft_real_2022 <= 0)) {
  stop("Clean home sales contain an invalid real price.", call. = FALSE)
}

setorder(home_sales, sale_date, row_id)
output_file <- sprintf("../output/home_sales_%d_%d.csv", start_year, end_year)
fwrite(home_sales, output_file, na = "NA")
cat(sprintf("Wrote %s clean home sales to %s.\n", format(nrow(home_sales), big.mark = ","), output_file))
