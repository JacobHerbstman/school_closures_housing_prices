suppressPackageStartupMessages(library(data.table))

clean_sales <- fread(
  "../input/home_sales_2006_2025.csv",
  colClasses = list(character = c("row_id", "pin"))
)
raw_sales <- fread(
  "../input/parcel_sales_2006_2025.csv",
  select = c(
    "row_id", "year", "class", "sale_price", "sale_deed_type", "sale_type",
    "sale_seller_name", "sale_buyer_name", "num_parcels_sale", "is_multisale",
    "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
    "sale_filter_deed_type"
  ),
  na.strings = NULL,
  colClasses = list(character = c(
    "row_id", "sale_price", "sale_seller_name", "sale_buyer_name"
  ))
)
external_benchmarks <- fread("../output/external_home_market_benchmarks.csv")

if (anyDuplicated(clean_sales$row_id) > 0L || anyDuplicated(raw_sales$row_id) > 0L) {
  stop("Sales inputs must be unique by row_id.", call. = FALSE)
}
if (!identical(sort(unique(clean_sales$sale_year)), 2006:2025)) {
  stop("Clean sales do not span every year from 2006 through 2025.", call. = FALSE)
}

clean_sales[, property_group := fcase(
  property_class %in% c(202:210, 234, 278, 295), "one_unit_or_rowhouse",
  property_class == 211L, "two_to_six_unit",
  property_class == 212L, "small_mixed_use",
  property_class == 299L, "condominium"
)]
if (anyNA(clean_sales$property_group)) {
  stop("A clean sale has an unrecognized residential property class.", call. = FALSE)
}

parse_boolean <- function(values, column_name) {
  normalized <- tolower(trimws(as.character(values)))
  if (any(!normalized %in% c("true", "false"))) {
    stop(sprintf("%s contains an invalid boolean value.", column_name), call. = FALSE)
  }
  normalized == "true"
}

raw_sales[, `:=`(
  sale_year = suppressWarnings(as.integer(year)),
  property_class = suppressWarnings(as.integer(class)),
  sale_price_nominal = suppressWarnings(as.numeric(gsub("[$,]", "", sale_price))),
  num_parcels_sale = suppressWarnings(as.integer(num_parcels_sale)),
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

raw_residential <- raw_sales[
  sale_year %between% c(2006L, 2025L) &
    property_class %in% c(202:212, 234, 278, 295, 299)
]
raw_quality_pass <- raw_residential[
  !sale_filter_same_sale_within_365 &
    !sale_filter_less_than_10k &
    !sale_filter_deed_type
]
raw_market_pass <- raw_quality_pass[
  is.finite(sale_price_nominal) &
    sale_price_nominal > 10000 &
    sale_type != "LAND"
]

invalid_party_names <- c("", "-", "UNKNOWN", "..")
raw_market_pass[, `:=`(
  sale_seller_name = trimws(sale_seller_name),
  sale_buyer_name = trimws(sale_buyer_name)
)]
raw_party_pass <- raw_market_pass[
  !toupper(sale_seller_name) %in% invalid_party_names &
    !toupper(sale_buyer_name) %in% invalid_party_names &
    toupper(sale_seller_name) != toupper(sale_buyer_name)
]
raw_deed_restricted_pass <- raw_market_pass[
  sale_deed_type %in% c("Warranty", "Trustee")
]
raw_legacy_pass <- raw_party_pass[
  sale_deed_type %in% c("Warranty", "Trustee")
]
raw_party_single_parcel <- raw_party_pass[num_parcels_sale == 1L & is_multisale == FALSE]
raw_deed_restricted_single_parcel <- raw_deed_restricted_pass[
  num_parcels_sale == 1L & is_multisale == FALSE
]
raw_legacy_single_parcel <- raw_legacy_pass[num_parcels_sale == 1L & is_multisale == FALSE]
raw_single_parcel_pass <- raw_market_pass[num_parcels_sale == 1L & is_multisale == FALSE]

# The all-home audit excludes single-PIN condo rows when Assessor
# characteristics cannot verify that the PIN represents a livable unit.
single_pin_clean_sales <- clean_sales[
  sale_sample_rule == "single_pin",
  .(row_id, sale_year)
]
unverified_condo_exclusions <- raw_single_parcel_pass[
  !single_pin_clean_sales,
  on = "row_id"
]
if (nrow(single_pin_clean_sales[!raw_single_parcel_pass, on = "row_id"]) > 0L ||
    any(unverified_condo_exclusions$property_class != 299L)) {
  stop("The clean single-PIN sample does not reconcile to the raw market-sale funnel.", call. = FALSE)
}

raw_annual <- raw_residential[, .(
  raw_residential_records = .N,
  same_sale_within_365_flagged_records = sum(sale_filter_same_sale_within_365),
  less_than_10k_flagged_records = sum(sale_filter_less_than_10k),
  deed_type_flagged_records = sum(sale_filter_deed_type)
), by = sale_year]
raw_annual <- merge(
  raw_annual,
  raw_quality_pass[, .(raw_quality_flag_pass_records = .N), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_market_pass[, .(raw_market_filter_pass_records = .N), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_party_pass[, .(raw_party_filter_pass_records = .N), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_party_single_parcel[, .(
    party_name_restricted_sales = .N,
    party_name_restricted_median_price = median(sale_price_nominal)
  ), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_deed_restricted_single_parcel[, .(deed_type_restricted_sales = .N), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_legacy_single_parcel[, .(
    legacy_restricted_sales = .N,
    legacy_restricted_median_price = median(sale_price_nominal)
  ), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  raw_single_parcel_pass[, .(
    raw_single_parcel_pass_records = .N,
    party_name_missing_or_unknown_sales = sum(
      toupper(sale_seller_name) %in% invalid_party_names |
        toupper(sale_buyer_name) %in% invalid_party_names
    ),
    same_party_name_sales = sum(
      !toupper(sale_seller_name) %in% invalid_party_names &
        !toupper(sale_buyer_name) %in% invalid_party_names &
        toupper(sale_seller_name) == toupper(sale_buyer_name)
    )
  ), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual <- merge(
  raw_annual,
  unverified_condo_exclusions[, .(
    unverified_single_pin_condos = .N
  ), by = sale_year],
  by = "sale_year",
  all = TRUE,
  sort = FALSE
)
raw_annual[is.na(unverified_single_pin_condos), unverified_single_pin_condos := 0L]

annual_benchmarks <- clean_sales[, .(
  cleaned_sales = .N,
  single_pin_cleaned_sales = sum(sale_sample_rule == "single_pin"),
  verified_condo_parking_sales = sum(
    sale_sample_rule == "verified_condo_with_parking"
  ),
  distinct_pins = uniqueN(pin),
  sale_price_p10 = as.numeric(quantile(sale_price_nominal, 0.10)),
  sale_price_p25 = as.numeric(quantile(sale_price_nominal, 0.25)),
  median_sale_price = median(sale_price_nominal),
  sale_price_p75 = as.numeric(quantile(sale_price_nominal, 0.75)),
  sale_price_p90 = as.numeric(quantile(sale_price_nominal, 0.90)),
  one_unit_or_rowhouse_sales = sum(property_group == "one_unit_or_rowhouse"),
  two_to_six_unit_sales = sum(property_group == "two_to_six_unit"),
  small_mixed_use_sales = sum(property_group == "small_mixed_use"),
  condominium_sales = sum(property_group == "condominium"),
  median_one_unit_or_rowhouse_price = median(
    sale_price_nominal[property_group == "one_unit_or_rowhouse"]
  ),
  median_two_to_six_unit_price = median(
    sale_price_nominal[property_group == "two_to_six_unit"]
  ),
  median_small_mixed_use_price = median(
    sale_price_nominal[property_group == "small_mixed_use"]
  ),
  median_condo_sale_price = median(sale_price_nominal[property_class == 299L]),
  median_noncondo_sale_price = median(sale_price_nominal[property_class != 299L]),
  condominium_share = mean(property_class == 299L),
  two_to_six_unit_building_share = mean(property_class == 211L),
  mixed_use_small_residential_share = mean(property_class == 212L),
  one_unit_or_rowhouse_share = mean(property_group == "one_unit_or_rowhouse"),
  verified_parking_share_of_condos = sum(
    sale_sample_rule == "verified_condo_with_parking"
  ) / sum(property_group == "condominium"),
  idor_refined_date_share = mean(is_mydec_date)
), by = sale_year]

annual_benchmarks <- raw_annual[
  annual_benchmarks,
  on = "sale_year"
]
if (nrow(annual_benchmarks) != 20L || anyNA(annual_benchmarks$raw_residential_records)) {
  stop("Raw-to-clean annual merge did not match all twenty years.", call. = FALSE)
}
if (any(
  annual_benchmarks$raw_single_parcel_pass_records !=
    annual_benchmarks$single_pin_cleaned_sales +
      annual_benchmarks$unverified_single_pin_condos
)) {
  stop("The audit funnel does not reproduce the clean task's single-PIN counts.", call. = FALSE)
}
if (any(
  annual_benchmarks$cleaned_sales !=
    annual_benchmarks$single_pin_cleaned_sales +
      annual_benchmarks$verified_condo_parking_sales
)) {
  stop("Clean sales contain a sample rule not represented in the audit.", call. = FALSE)
}
annual_benchmarks[, `:=`(
  same_sale_within_365_flagged_share =
    same_sale_within_365_flagged_records / raw_residential_records,
  less_than_10k_flagged_share =
    less_than_10k_flagged_records / raw_residential_records,
  deed_type_flagged_share =
    deed_type_flagged_records / raw_residential_records,
  quality_flag_pass_share = raw_quality_flag_pass_records / raw_residential_records,
  market_filter_pass_share =
    raw_market_filter_pass_records / raw_quality_flag_pass_records,
  party_filter_pass_share =
    raw_party_filter_pass_records / raw_market_filter_pass_records,
  deed_type_restriction_pass_share =
    deed_type_restricted_sales / raw_single_parcel_pass_records,
  legacy_retention_share =
    legacy_restricted_sales / raw_single_parcel_pass_records,
  single_parcel_pass_share =
    raw_single_parcel_pass_records / raw_market_filter_pass_records,
  clean_retention_share = cleaned_sales / raw_residential_records
)]

zillow_monthly <- external_benchmarks[source == "Zillow"]
zillow_monthly[, `:=`(
  date = as.IDate(period),
  sale_year = as.integer(substr(period, 1L, 4L))
)]
if (anyNA(zillow_monthly$date)) {
  stop("A Zillow benchmark has an invalid month.", call. = FALSE)
}

clean_sales[, sale_month_date := as.IDate(sprintf(
  "%04d-%02d-01",
  sale_year,
  sale_month
))]
if (anyNA(clean_sales$sale_month_date)) {
  stop("A clean sale cannot be assigned to a calendar month.", call. = FALSE)
}

monthly_benchmarks <- clean_sales[, .(
  monthly_sales = .N,
  monthly_median_sale_price = median(sale_price_nominal),
  monthly_one_unit_or_rowhouse_sales = sum(property_group == "one_unit_or_rowhouse"),
  monthly_two_to_six_unit_sales = sum(property_group == "two_to_six_unit"),
  monthly_small_mixed_use_sales = sum(property_group == "small_mixed_use"),
  monthly_condominium_sales = sum(property_group == "condominium")
), by = sale_month_date]
setorder(monthly_benchmarks, sale_month_date)
if (nrow(monthly_benchmarks) != 240L ||
    !identical(
      monthly_benchmarks$sale_month_date,
      seq(as.IDate("2006-01-01"), as.IDate("2025-12-01"), by = "month")
    )) {
  stop("Clean monthly sales do not span every month from 2006 through 2025.", call. = FALSE)
}

zillow_monthly[, year_month := substr(period, 1L, 7L)]
zillow_monthly_wide <- dcast(
  zillow_monthly[sale_year %between% c(2006L, 2025L)],
  year_month ~ series,
  value.var = "value"
)
zillow_monthly_wide[, sale_month_date := as.IDate(paste0(year_month, "-01"))]
if (anyDuplicated(zillow_monthly_wide$sale_month_date) > 0L) {
  stop("Zillow monthly benchmarks are not unique by month.", call. = FALSE)
}
setnames(
  zillow_monthly_wide,
  c("home_value_index", "median_sale_price", "sales_count_nowcast"),
  c("zillow_zhvi", "zillow_median_sale_price", "zillow_msa_sales_count")
)
monthly_benchmarks <- merge(
  monthly_benchmarks,
  zillow_monthly_wide[, .(
    sale_month_date,
    zillow_zhvi,
    zillow_median_sale_price,
    zillow_msa_sales_count
  )],
  by = "sale_month_date",
  all.x = TRUE,
  sort = TRUE
)
if (nrow(monthly_benchmarks) != 240L) {
  stop("The Zillow join changed the number of Chicago sale months.", call. = FALSE)
}

monthly_benchmarks[, `:=`(
  chicago_price_rolling_12_month = frollmean(
    monthly_median_sale_price,
    12L,
    align = "right"
  ),
  zillow_sale_price_rolling_12_month = frollmean(
    zillow_median_sale_price,
    12L,
    align = "right"
  ),
  zillow_zhvi_rolling_12_month = frollmean(
    zillow_zhvi,
    12L,
    align = "right"
  ),
  chicago_sales_rolling_12_month = frollsum(monthly_sales, 12L, align = "right"),
  zillow_msa_sales_rolling_12_month = frollsum(
    zillow_msa_sales_count,
    12L,
    align = "right"
  ),
  chicago_price_yoy_log_change = 100 * (
    log(monthly_median_sale_price) - shift(log(monthly_median_sale_price), 12L)
  ),
  zillow_sale_price_yoy_log_change = 100 * (
    log(zillow_median_sale_price) - shift(log(zillow_median_sale_price), 12L)
  ),
  zillow_zhvi_yoy_log_change = 100 * (
    log(zillow_zhvi) - shift(log(zillow_zhvi), 12L)
  ),
  chicago_sales_yoy_log_change = 100 * (
    log(monthly_sales) - shift(log(monthly_sales), 12L)
  ),
  zillow_msa_sales_yoy_log_change = 100 * (
    log(zillow_msa_sales_count) - shift(log(zillow_msa_sales_count), 12L)
  )
)]

count_base <- monthly_benchmarks[as.integer(format(sale_month_date, "%Y")) == 2010L]
monthly_benchmarks[, `:=`(
  chicago_sales_rolling_index_2010 =
    100 * chicago_sales_rolling_12_month /
      mean(count_base$chicago_sales_rolling_12_month),
  zillow_msa_sales_rolling_index_2010 =
    100 * zillow_msa_sales_rolling_12_month /
      mean(count_base$zillow_msa_sales_rolling_12_month)
)]

zillow_zhvi <- zillow_monthly[
  series == "home_value_index" & sale_year %between% c(2006L, 2025L),
  .(zillow_zhvi = mean(value), zillow_zhvi_months = .N),
  by = sale_year
]
zillow_sale_price <- zillow_monthly[
  series == "median_sale_price" & sale_year %between% c(2008L, 2025L),
  .(
    zillow_median_sale_price = median(value),
    zillow_sale_price_months = .N
  ),
  by = sale_year
]
zillow_sales_count <- zillow_monthly[
  series == "sales_count_nowcast" & sale_year %between% c(2008L, 2025L),
  .(
    zillow_msa_sales_count = sum(value),
    zillow_sales_count_months = .N
  ),
  by = sale_year
]

if (any(zillow_zhvi$zillow_zhvi_months != 12L) ||
    any(zillow_sale_price[sale_year > 2008L, zillow_sale_price_months] != 12L) ||
    any(zillow_sales_count[sale_year > 2008L, zillow_sales_count_months] != 12L)) {
  stop("A complete Zillow comparison year is missing a month.", call. = FALSE)
}

annual_benchmarks <- zillow_zhvi[annual_benchmarks, on = "sale_year"]
annual_benchmarks <- zillow_sale_price[annual_benchmarks, on = "sale_year"]
annual_benchmarks <- zillow_sales_count[annual_benchmarks, on = "sale_year"]
setorder(annual_benchmarks, sale_year)

base_year <- annual_benchmarks[sale_year == 2010L]
annual_benchmarks[, `:=`(
  sale_price_index_2010 = 100 * median_sale_price / base_year$median_sale_price,
  legacy_sale_price_index_2010 =
    100 * legacy_restricted_median_price / base_year$legacy_restricted_median_price,
  zillow_sale_price_index_2010 = 100 * zillow_median_sale_price / base_year$zillow_median_sale_price,
  zillow_zhvi_index_2010 = 100 * zillow_zhvi / base_year$zillow_zhvi,
  sales_count_index_2010 = 100 * cleaned_sales / base_year$cleaned_sales,
  legacy_restricted_sales_count_index_2010 =
    100 * legacy_restricted_sales / base_year$legacy_restricted_sales,
  zillow_msa_sales_count_index_2010 = 100 * zillow_msa_sales_count / base_year$zillow_msa_sales_count
)]
annual_benchmarks[, `:=`(
  sale_price_log_change = c(NA_real_, 100 * diff(log(median_sale_price))),
  legacy_sale_price_log_change = c(
    NA_real_,
    100 * diff(log(legacy_restricted_median_price))
  ),
  zillow_sale_price_log_change = c(NA_real_, 100 * diff(log(zillow_median_sale_price))),
  zillow_zhvi_log_change = c(NA_real_, 100 * diff(log(zillow_zhvi))),
  sales_count_log_change = c(NA_real_, 100 * diff(log(cleaned_sales))),
  legacy_restricted_sales_count_log_change =
    c(NA_real_, 100 * diff(log(legacy_restricted_sales))),
  zillow_msa_sales_count_log_change = c(NA_real_, 100 * diff(log(zillow_msa_sales_count)))
)]

acs_value <- external_benchmarks[
  source == "ACS 1-year" & series == "median_owner_occupied_value"
]
if (nrow(acs_value) != 1L || acs_value$period != "2024") {
  stop("Expected one 2024 ACS median owner-occupied value.", call. = FALSE)
}
annual_benchmarks[, `:=`(
  acs_median_owner_occupied_value = fifelse(
    sale_year == 2024L,
    acs_value$value,
    NA_real_
  ),
  acs_median_owner_occupied_value_moe = fifelse(
    sale_year == 2024L,
    acs_value$margin_of_error,
    NA_real_
  )
)]

sales_composition <- clean_sales[sale_year == 2024L, .N, by = .(
  category = fcase(
    property_class %in% c(202:210, 234, 278, 295),
      "One-unit residence or rowhouse",
    property_class == 211L, "Two-to-six-unit building class 211",
    property_class == 212L, "Small mixed-use residential class 212",
    property_class == 299L, "Condominium class 299"
  )
)]
sales_composition[, `:=`(
  source = "Chicago 2024 sales",
  unit = "transactions",
  share = N / sum(N),
  count_margin_of_error = NA_real_
)]
setnames(sales_composition, "N", "count")

acs_structure <- external_benchmarks[
  source == "ACS 1-year" & grepl("^owner_occupied_", series)
]
acs_lookup <- setNames(acs_structure$value, acs_structure$series)
acs_moe_lookup <- setNames(acs_structure$margin_of_error, acs_structure$series)
acs_total <- acs_lookup[["owner_occupied_units_total"]]

acs_composition <- data.table(
  category = c(
    "One-unit detached or attached",
    "Two-to-four-unit structure",
    "Five-or-more-unit structure",
    "Mobile home, boat, RV, or other"
  ),
  count = c(
    acs_lookup[["owner_occupied_one_unit_detached"]] +
      acs_lookup[["owner_occupied_one_unit_attached"]],
    acs_lookup[["owner_occupied_two_units"]] +
      acs_lookup[["owner_occupied_three_to_four_units"]],
    acs_lookup[["owner_occupied_five_to_nine_units"]] +
      acs_lookup[["owner_occupied_ten_to_nineteen_units"]] +
      acs_lookup[["owner_occupied_twenty_to_forty_nine_units"]] +
      acs_lookup[["owner_occupied_fifty_or_more_units"]],
    acs_lookup[["owner_occupied_mobile_home"]] +
      acs_lookup[["owner_occupied_boat_rv_other"]]
  ),
  count_margin_of_error = c(
    sqrt(acs_moe_lookup[["owner_occupied_one_unit_detached"]]^2 +
      acs_moe_lookup[["owner_occupied_one_unit_attached"]]^2),
    sqrt(acs_moe_lookup[["owner_occupied_two_units"]]^2 +
      acs_moe_lookup[["owner_occupied_three_to_four_units"]]^2),
    sqrt(acs_moe_lookup[["owner_occupied_five_to_nine_units"]]^2 +
      acs_moe_lookup[["owner_occupied_ten_to_nineteen_units"]]^2 +
      acs_moe_lookup[["owner_occupied_twenty_to_forty_nine_units"]]^2 +
      acs_moe_lookup[["owner_occupied_fifty_or_more_units"]]^2),
    sqrt(acs_moe_lookup[["owner_occupied_mobile_home"]]^2 +
      acs_moe_lookup[["owner_occupied_boat_rv_other"]]^2)
  )
)
acs_composition[, `:=`(
  source = "ACS 2024 owner-occupied stock",
  unit = "housing units",
  share = count / acs_total
)]

composition <- rbindlist(
  list(sales_composition, acs_composition),
  use.names = TRUE
)
if (abs(sum(sales_composition$share) - 1) > 1e-10 ||
    abs(sum(acs_composition$share) - 1) > 1e-10) {
  stop("A 2024 composition distribution does not sum to one.", call. = FALSE)
}

correlation_row <- function(
    data,
    period_column,
    first_period,
    frequency,
    comparison,
    transformation,
    chicago_column,
    benchmark_column,
    caveat) {
  comparison_data <- data[
    data[[period_column]] >= first_period &
      complete.cases(data[[chicago_column]], data[[benchmark_column]])
  ]
  if (nrow(comparison_data) < 3L) {
    stop(sprintf("Too few observations for %s.", comparison), call. = FALSE)
  }
  data.table(
    frequency = frequency,
    comparison = comparison,
    transformation = transformation,
    first_period = as.character(comparison_data[[period_column]][1L]),
    last_period = as.character(comparison_data[[period_column]][nrow(comparison_data)]),
    observations = nrow(comparison_data),
    pearson_correlation = cor(
      comparison_data[[chicago_column]],
      comparison_data[[benchmark_column]],
      method = "pearson"
    ),
    spearman_correlation = cor(
      comparison_data[[chicago_column]],
      comparison_data[[benchmark_column]],
      method = "spearman"
    ),
    caveat = caveat
  )
}

correlations <- rbindlist(list(
  correlation_row(
    annual_benchmarks, "sale_year", 2009L, "annual",
    "Chicago median sale price vs Zillow city median sale price",
    "nominal level", "median_sale_price", "zillow_median_sale_price",
    "Both series trend; a high level correlation is weak validation."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2010L, "annual",
    "Chicago median sale price vs Zillow city median sale price",
    "one-year log change (percent)", "sale_price_log_change",
    "zillow_sale_price_log_change",
    "Zillow and project samples need not contain the same transactions."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2006L, "annual",
    "Chicago median sale price vs Zillow city ZHVI",
    "nominal level", "median_sale_price", "zillow_zhvi",
    "ZHVI is a modeled stock-value measure, not a transaction median."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2007L, "annual",
    "Chicago median sale price vs Zillow city ZHVI",
    "one-year log change (percent)", "sale_price_log_change",
    "zillow_zhvi_log_change",
    "ZHVI is a modeled stock-value measure, not a transaction median."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2009L, "annual",
    "Chicago sales vs Zillow Chicago MSA sales",
    "2010 index level", "sales_count_index_2010",
    "zillow_msa_sales_count_index_2010",
    "The project covers Chicago city; Zillow covers the metropolitan area."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2010L, "annual",
    "Chicago sales vs Zillow Chicago MSA sales",
    "one-year log change (percent)", "sales_count_log_change",
    "zillow_msa_sales_count_log_change",
    "The project covers Chicago city; Zillow covers the metropolitan area."
  ),
  correlation_row(
    annual_benchmarks, "sale_year", 2010L, "annual",
    "Chicago sales under old restrictions vs Zillow Chicago MSA sales",
    "one-year log change (percent)",
    "legacy_restricted_sales_count_log_change",
    "zillow_msa_sales_count_log_change",
    "Old restrictions are an audit sensitivity, not the production sample."
  ),
  correlation_row(
    monthly_benchmarks, "sale_month_date", as.IDate("2009-02-01"), "monthly",
    "Chicago median sale price vs Zillow city median sale price",
    "12-month log change (percent)", "chicago_price_yoy_log_change",
    "zillow_sale_price_yoy_log_change",
    "Monthly transaction medians are noisy and samples need not coincide."
  ),
  correlation_row(
    monthly_benchmarks, "sale_month_date", as.IDate("2007-01-01"), "monthly",
    "Chicago median sale price vs Zillow city ZHVI",
    "12-month log change (percent)", "chicago_price_yoy_log_change",
    "zillow_zhvi_yoy_log_change",
    "ZHVI is a modeled stock-value measure, not a transaction median."
  ),
  correlation_row(
    monthly_benchmarks, "sale_month_date", as.IDate("2009-02-01"), "monthly",
    "Chicago sales vs Zillow Chicago MSA sales",
    "12-month log change (percent)", "chicago_sales_yoy_log_change",
    "zillow_msa_sales_yoy_log_change",
    "The project covers Chicago city; Zillow covers the metropolitan area."
  )
), use.names = TRUE)

annual_price_growth <- correlations[
  frequency == "annual" &
    comparison == "Chicago median sale price vs Zillow city median sale price" &
    transformation == "one-year log change (percent)"
]
annual_zhvi_growth <- correlations[
  frequency == "annual" &
    comparison == "Chicago median sale price vs Zillow city ZHVI" &
    transformation == "one-year log change (percent)"
]
annual_count_growth <- correlations[
  frequency == "annual" &
    comparison == "Chicago sales vs Zillow Chicago MSA sales" &
    transformation == "one-year log change (percent)"
]
legacy_count_growth <- correlations[
  frequency == "annual" &
    comparison == "Chicago sales under old restrictions vs Zillow Chicago MSA sales"
]
cat(sprintf(
  "Annual price-growth correlation, Chicago versus Zillow median sale price: %.3f\n",
  annual_price_growth$pearson_correlation
))
cat(sprintf(
  "Annual price-growth correlation, Chicago versus Zillow ZHVI: %.3f\n",
  annual_zhvi_growth$pearson_correlation
))
cat(sprintf(
  "Annual sales-count growth correlation, Chicago city versus Zillow Chicago MSA: %.3f\n",
  annual_count_growth$pearson_correlation
))
cat(sprintf(
  "Annual sales-count growth correlation under the old deed and party-name rules: %.3f\n",
  legacy_count_growth$pearson_correlation
))
cat(sprintf(
  "2024 median sale price: $%s; ACS median owner-occupied value: $%s.\n",
  format(annual_benchmarks[sale_year == 2024L, median_sale_price], big.mark = ","),
  format(acs_value$value, big.mark = ",")
))

annual_temporary <- "../output/annual_home_sales_benchmarks.csv.tmp"
monthly_temporary <- "../output/monthly_home_sales_benchmarks.csv.tmp"
composition_temporary <- "../output/home_sales_composition_2024.csv.tmp"
correlations_temporary <- "../output/home_sales_external_correlations.csv.tmp"
on.exit(unlink(c(
  annual_temporary,
  monthly_temporary,
  composition_temporary,
  correlations_temporary
)), add = TRUE)
fwrite(annual_benchmarks, annual_temporary)
fwrite(monthly_benchmarks, monthly_temporary)
fwrite(composition, composition_temporary)
fwrite(correlations, correlations_temporary)
if (!file.rename(annual_temporary, "../output/annual_home_sales_benchmarks.csv") ||
    !file.rename(monthly_temporary, "../output/monthly_home_sales_benchmarks.csv") ||
    !file.rename(composition_temporary, "../output/home_sales_composition_2024.csv") ||
    !file.rename(correlations_temporary, "../output/home_sales_external_correlations.csv")) {
  stop("Could not move completed benchmark tables into place.", call. = FALSE)
}
