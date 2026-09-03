suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop(
    "Usage: Rscript audit_home_sales_sample_definition.R START_YEAR END_YEAR",
    call. = FALSE
  )
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

transactions <- fread(
  "../input/home_sales_with_characteristics_2006_2025.csv",
  colClasses = list(character = c(
    "row_id", "pin", "sale_document_num", "res_char_apts"
  ))
)
if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Characterized transactions must be nonempty and unique by row_id.", call. = FALSE)
}

required_columns <- c(
  "sale_year", "sale_price_nominal", "sale_type", "property_class",
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

attrition <- data.table(
  step = "Characterized transactions in study period",
  sales = transactions[sale_year %between% c(start_year, end_year), .N]
)
sample <- transactions[sale_year %between% c(start_year, end_year)]

sample <- sample[
  sale_filter_same_sale_within_365 == FALSE &
    sale_filter_less_than_10k == FALSE &
    sale_filter_deed_type == FALSE
]
attrition <- rbind(
  attrition,
  data.table(step = "Pass Cook County sale-quality flags", sales = nrow(sample))
)

sample <- sample[
  is.finite(sale_price_nominal) & sale_price_nominal > 10000 &
    !is.na(sale_type) & sale_type != "LAND"
]
attrition <- rbind(
  attrition,
  data.table(step = "Non-land sale above $10,000", sales = nrow(sample))
)

sample <- sample[single_improvement_card == TRUE]
attrition <- rbind(
  attrition,
  data.table(step = "Require one improvement card", sales = nrow(sample))
)

sample <- sample[property_class != 212L]
attrition <- rbind(
  attrition,
  data.table(step = "Exclude class 212 mixed-use", sales = nrow(sample))
)

complete_core_hedonics <-
  is.finite(sample$res_char_yrblt) &
  is.finite(sample$res_char_bldg_sf) & sample$res_char_bldg_sf > 0 &
  is.finite(sample$res_char_land_sf) & sample$res_char_land_sf > 0 &
  is.finite(sample$res_char_beds) &
  is.finite(sample$res_char_rooms) &
  is.finite(sample$res_char_fbath) &
  !is.na(sample$res_char_type_resd) & nzchar(trimws(sample$res_char_type_resd)) &
  !is.na(sample$res_char_cnst_qlty) & nzchar(trimws(sample$res_char_cnst_qlty)) &
  !is.na(sample$res_char_repair_cnd) & nzchar(trimws(sample$res_char_repair_cnd))
sample <- sample[complete_core_hedonics]
attrition <- rbind(
  attrition,
  data.table(step = "Require complete core hedonics", sales = nrow(sample))
)

apartment_count_labels <- c("Two", "Three", "Four", "Five", "Six")
sample <- sample[
  property_class != 211L | res_char_apts %chin% apartment_count_labels
]
attrition <- rbind(
  attrition,
  data.table(step = "Require class 211 apartment count", sales = nrow(sample))
)

sample[, price_per_sqft := sale_price_nominal / res_char_bldg_sf]
if (any(!is.finite(sample$price_per_sqft) | sample$price_per_sqft <= 0)) {
  stop("Candidate sample contains a nonpositive or undefined price per square foot.", call. = FALSE)
}

sample[, internally_inconsistent_rooms := res_char_rooms < res_char_beds]
sample[, implausibly_high_price_per_sqft := price_per_sqft > 5000]
sample[, production_exclusion :=
  internally_inconsistent_rooms | implausibly_high_price_per_sqft]
sample[, production_exclusion_reason := fcase(
  internally_inconsistent_rooms & implausibly_high_price_per_sqft,
  "rooms_below_bedrooms;price_per_sqft_above_5000",
  internally_inconsistent_rooms,
  "rooms_below_bedrooms",
  implausibly_high_price_per_sqft,
  "price_per_sqft_above_5000",
  default = ""
)]

attrition <- rbind(
  attrition,
  data.table(
    step = "Exclude confirmed price or characteristic errors",
    sales = sample[production_exclusion == FALSE, .N]
  )
)
attrition[, removed_at_step := shift(sales, fill = sales[1L]) - sales]
attrition[, retained_share_of_study_period := sales / sales[1L]]

sample[, property_group := fifelse(
  property_class == 211L,
  "Class 211: two-to-six-unit",
  "Single-family or townhouse"
)]
price_summary <- sample[, {
  list(
    sales = .N,
    price_per_sqft_min = min(price_per_sqft),
    price_per_sqft_p01 = as.numeric(quantile(price_per_sqft, 0.01)),
    price_per_sqft_p50 = median(price_per_sqft),
    price_per_sqft_p99 = as.numeric(quantile(price_per_sqft, 0.99)),
    price_per_sqft_max = max(price_per_sqft),
    below_5 = sum(price_per_sqft < 5),
    above_2000 = sum(price_per_sqft > 2000),
    above_5000 = sum(price_per_sqft > 5000),
    rooms_below_bedrooms = sum(internally_inconsistent_rooms),
    production_exclusions = sum(production_exclusion)
  )
}, by = property_group]

other_prices <- transactions[
  is.finite(sale_price_nominal) & sale_price_nominal > 10000,
  .(
    pin_sale_count = .N,
    pin_median_recorded_price = median(sale_price_nominal)
  ),
  by = pin
]
review <- sample[
  price_per_sqft < 5 | price_per_sqft > 2000 | internally_inconsistent_rooms
]
review <- merge(review, other_prices, by = "pin", all.x = TRUE, sort = FALSE)
review[, price_to_pin_median := sale_price_nominal / pin_median_recorded_price]
setorder(review, production_exclusion, price_per_sqft, row_id)

review_columns <- c(
  "production_exclusion", "production_exclusion_reason", "row_id", "pin",
  "sale_document_num", "sale_date", "sale_year", "property_class",
  "property_group", "sale_price_nominal", "res_char_bldg_sf",
  "price_per_sqft", "res_char_land_sf", "res_char_yrblt", "res_char_beds",
  "res_char_rooms", "res_char_fbath", "res_char_apts", "sale_deed_type",
  "mydec_deed_type", "pin_sale_count", "pin_median_recorded_price",
  "price_to_pin_median"
)

fwrite(
  attrition,
  sprintf("../output/sample_attrition_%d_%d.csv", start_year, end_year)
)
fwrite(
  price_summary,
  sprintf("../output/price_per_sqft_summary_%d_%d.csv", start_year, end_year)
)
fwrite(
  review[, ..review_columns],
  sprintf("../output/outlier_review_%d_%d.csv", start_year, end_year)
)

plot_sample <- sample[price_per_sqft %between% c(1, 5000)]
png(
  sprintf("../output/price_per_sqft_distribution_%d_%d.png", start_year, end_year),
  width = 1800,
  height = 900,
  res = 180
)
par(mfrow = c(1, 2), mar = c(5, 5, 2, 1), oma = c(0, 0, 2, 0), las = 1)
for (group_value in unique(plot_sample$property_group)) {
  group_data <- plot_sample[property_group == group_value, price_per_sqft]
  hist(
    log(group_data),
    breaks = 80,
    col = "grey75",
    border = "white",
    xlim = log(c(1, 6000)),
    main = group_value,
    xlab = "Log nominal price per building square foot"
  )
  abline(v = log(c(5, 5000)), col = c("#2166ac", "#b2182b"), lwd = 2, lty = 2)
}
mtext(
  "Dashed lines: $5 review threshold (blue); $5,000 exclusion threshold (red)",
  side = 3,
  outer = TRUE,
  line = 0.2
)
dev.off()

cat(sprintf(
  "Candidate sample: %s sales; production integrity exclusions: %s; retained: %s.\n",
  format(nrow(sample), big.mark = ","),
  format(sum(sample$production_exclusion), big.mark = ","),
  format(sum(!sample$production_exclusion), big.mark = ",")
))
