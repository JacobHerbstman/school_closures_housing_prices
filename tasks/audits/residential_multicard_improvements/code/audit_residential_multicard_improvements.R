suppressPackageStartupMessages(library(data.table))

improvements <- fread(
  "../input/residential_improvements_2006_2025.csv",
  colClasses = list(character = c("pin", "tieback_key_pin"))
)
master_transactions <- fread(
  "../input/master_home_transactions_2006_2025.csv",
  select = c("row_id", "pin", "sale_year", "property_class", "property_type"),
  colClasses = list(character = c("row_id", "pin"))
)
clean_sales <- fread(
  "../input/home_sales_2006_2025.csv",
  select = c("row_id", "pin", "sale_year", "property_class", "property_type"),
  colClasses = list(character = c("row_id", "pin"))
)

if (anyDuplicated(improvements[, .(pin, year, card)]) > 0L) {
  stop("Residential improvements must be unique by PIN, year, and card.", call. = FALSE)
}
if (anyDuplicated(master_transactions$row_id) > 0L ||
    anyDuplicated(clean_sales$row_id) > 0L) {
  stop("Transaction inputs must be unique by row_id.", call. = FALSE)
}

master_noncondo <- master_transactions[property_type != "condominium"]
clean_noncondo <- clean_sales[property_type != "condominium"]
master_key_check <- master_noncondo[, .(
  property_classes = uniqueN(property_class),
  property_types = uniqueN(property_type)
), by = .(pin, year = sale_year)]
if (any(master_key_check$property_classes != 1L) ||
    any(master_key_check$property_types != 1L)) {
  stop("A master PIN-year has conflicting property classifications.", call. = FALSE)
}
master_keys <- master_noncondo[, .(
  property_class = first(property_class),
  property_type = first(property_type)
), by = .(pin, year = sale_year)]

source_key_check <- improvements[, .(
  card_count = .N,
  reported_card_count_values = uniqueN(pin_num_cards),
  reported_multicard_values = uniqueN(pin_is_multicard),
  reported_card_count = first(pin_num_cards),
  reported_multicard = first(pin_is_multicard)
), by = .(pin, year)]
if (any(source_key_check$reported_card_count_values != 1L) ||
    any(source_key_check$reported_multicard_values != 1L) ||
    any(source_key_check$reported_card_count != source_key_check$card_count) ||
    any(source_key_check$reported_multicard != (source_key_check$card_count > 1L))) {
  stop("Assessor multicard metadata does not reproduce the returned card rows.", call. = FALSE)
}

sum_or_missing <- function(values) {
  if (all(is.na(values))) NA_real_ else as.numeric(sum(values, na.rm = TRUE))
}
min_or_missing <- function(values) {
  if (all(is.na(values))) NA_real_ else as.numeric(min(values, na.rm = TRUE))
}
max_or_missing <- function(values) {
  if (all(is.na(values))) NA_real_ else as.numeric(max(values, na.rm = TRUE))
}

physical_columns <- grep("^char_", names(improvements), value = TRUE)
key_characteristics <- improvements[, .(
  card_count = .N,
  card_numbers_are_consecutive = identical(sort(card), seq_len(.N)),
  physical_profile_count = uniqueN(.SD),
  card_class_count = uniqueN(class),
  land_sqft_value_count = uniqueN(char_land_sf),
  total_building_sqft = sum_or_missing(char_bldg_sf),
  largest_building_sqft = max_or_missing(char_bldg_sf),
  largest_card = if (all(is.na(char_bldg_sf))) {
    NA_integer_
  } else {
    as.integer(min(card[char_bldg_sf == max(char_bldg_sf, na.rm = TRUE)]))
  },
  land_sqft = if (uniqueN(char_land_sf) == 1L) first(char_land_sf) else NA_real_,
  earliest_year_built = min_or_missing(char_yrblt),
  latest_year_built = max_or_missing(char_yrblt),
  total_bedrooms = sum_or_missing(char_beds),
  total_rooms = sum_or_missing(char_rooms),
  total_full_baths = sum_or_missing(char_fbath),
  total_half_baths = sum_or_missing(char_hbath),
  total_fireplaces = sum_or_missing(char_frpl),
  total_commercial_units = sum_or_missing(char_ncu),
  nonzero_card_proration_count = sum(
    !is.na(card_proration_rate) & card_proration_rate != 0
  ),
  card_proration_sum = sum_or_missing(card_proration_rate),
  tieback_proration_value_count = uniqueN(tieback_proration_rate)
), by = .(pin, year), .SDcols = physical_columns]

multicard_cases <- key_characteristics[card_count > 1L]
if (nrow(multicard_cases) == 0L) {
  stop("The residential-improvement source contains no multicard PIN-years.", call. = FALSE)
}
if (any(multicard_cases$land_sqft_value_count != 1L) ||
    any(multicard_cases$tieback_proration_value_count != 1L)) {
  stop("A multicard PIN-year has inconsistent parcel-level characteristics.", call. = FALSE)
}
multicard_cases[, `:=`(
  largest_building_share = largest_building_sqft / total_building_sqft,
  card_one_is_largest = largest_card == 1L,
  has_repeated_physical_profile = physical_profile_count < card_count,
  has_multiple_card_classes = card_class_count > 1L
)]

multicard_cases <- merge(
  multicard_cases,
  master_keys,
  by = c("pin", "year"),
  all.x = TRUE,
  sort = FALSE
)
if (anyNA(multicard_cases$property_class)) {
  stop("A multicard improvement PIN-year does not match the master universe.", call. = FALSE)
}

clean_key_counts <- clean_noncondo[, .(clean_transactions = .N), by = .(
  pin,
  year = sale_year
)]
multicard_cases <- merge(
  multicard_cases,
  clean_key_counts,
  by = c("pin", "year"),
  all.x = TRUE,
  sort = FALSE
)
multicard_cases[is.na(clean_transactions), clean_transactions := 0L]
setorder(multicard_cases, year, pin)

requested_by_class <- master_keys[, .(
  requested_pin_years = .N
), by = property_class]
multicard_by_class <- multicard_cases[, .(
  multicard_pin_years = .N,
  median_card_count = as.numeric(median(card_count)),
  two_card_share = mean(card_count == 2L),
  consecutive_card_number_share = mean(card_numbers_are_consecutive),
  card_one_largest_share = mean(card_one_is_largest, na.rm = TRUE),
  median_largest_building_share = median(largest_building_share, na.rm = TRUE),
  repeated_physical_profile_share = mean(has_repeated_physical_profile),
  multiple_card_class_share = mean(has_multiple_card_classes),
  nonzero_card_proration_share = mean(nonzero_card_proration_count > 0L)
), by = property_class]
clean_by_class <- clean_noncondo[, .(clean_sales = .N), by = property_class]
clean_noncondo[, year := sale_year]
clean_multicard <- merge(
  clean_noncondo,
  multicard_cases[, .(pin, year)],
  by = c("pin", "year"),
  all = FALSE,
  sort = FALSE
)
clean_multicard_by_class <- clean_multicard[, .(
  clean_multicard_sales = .N
), by = property_class]

multicard_by_class <- Reduce(
  function(left, right) merge(
    left,
    right,
    by = "property_class",
    all = TRUE,
    sort = FALSE
  ),
  list(
    requested_by_class,
    multicard_by_class,
    clean_by_class,
    clean_multicard_by_class
  )
)
multicard_by_class[is.na(multicard_pin_years), multicard_pin_years := 0L]
multicard_by_class[is.na(clean_multicard_sales), clean_multicard_sales := 0L]
multicard_by_class[, `:=`(
  property_class_label = sprintf("Class %d", property_class),
  multicard_pin_year_share = multicard_pin_years / requested_pin_years,
  clean_multicard_sales_share = clean_multicard_sales / clean_sales
)]

overall <- data.table(
  property_class = NA_integer_,
  requested_pin_years = nrow(master_keys),
  multicard_pin_years = nrow(multicard_cases),
  median_card_count = as.numeric(median(multicard_cases$card_count)),
  two_card_share = mean(multicard_cases$card_count == 2L),
  consecutive_card_number_share = mean(multicard_cases$card_numbers_are_consecutive),
  card_one_largest_share = mean(multicard_cases$card_one_is_largest, na.rm = TRUE),
  median_largest_building_share = median(
    multicard_cases$largest_building_share,
    na.rm = TRUE
  ),
  repeated_physical_profile_share = mean(
    multicard_cases$has_repeated_physical_profile
  ),
  multiple_card_class_share = mean(multicard_cases$has_multiple_card_classes),
  nonzero_card_proration_share = mean(
    multicard_cases$nonzero_card_proration_count > 0L
  ),
  clean_sales = nrow(clean_noncondo),
  clean_multicard_sales = sum(multicard_cases$clean_transactions),
  property_class_label = "All non-condo classes",
  multicard_pin_year_share = nrow(multicard_cases) / nrow(master_keys),
  clean_multicard_sales_share =
    sum(multicard_cases$clean_transactions) / nrow(clean_noncondo)
)
multicard_by_class <- rbindlist(
  list(overall, multicard_by_class),
  use.names = TRUE,
  fill = TRUE
)
setcolorder(multicard_by_class, c(
  "property_class", "property_class_label", "requested_pin_years",
  "multicard_pin_years", "multicard_pin_year_share", "clean_sales",
  "clean_multicard_sales", "clean_multicard_sales_share",
  "median_card_count", "two_card_share", "consecutive_card_number_share",
  "card_one_largest_share", "median_largest_building_share",
  "repeated_physical_profile_share", "multiple_card_class_share",
  "nonzero_card_proration_share"
))
class_rows <- multicard_by_class[!is.na(property_class)]
setorder(class_rows, property_class)
multicard_by_class <- rbind(
  multicard_by_class[is.na(property_class)],
  class_rows
)

case_temporary <- "../output/residential_multicard_pin_years.csv.tmp"
class_temporary <- "../output/residential_multicard_by_class.csv.tmp"
unlink(c(case_temporary, class_temporary))
fwrite(multicard_cases, case_temporary)
fwrite(multicard_by_class, class_temporary)
if (!file.rename(case_temporary, "../output/residential_multicard_pin_years.csv") ||
    !file.rename(class_temporary, "../output/residential_multicard_by_class.csv")) {
  stop("Could not move completed multicard audit tables into place.", call. = FALSE)
}

cat(sprintf(
  "%s of %s clean non-condo sales (%.2f percent) have multiple cards.\n",
  format(sum(multicard_cases$clean_transactions), big.mark = ","),
  format(nrow(clean_noncondo), big.mark = ","),
  100 * sum(multicard_cases$clean_transactions) / nrow(clean_noncondo)
))
cat(sprintf(
  "Card 1 is the largest building in %.2f percent of multicard PIN-years.\n",
  100 * mean(multicard_cases$card_one_is_largest, na.rm = TRUE)
))
cat(sprintf(
  "Only %.2f percent have any nonzero card-proration rate.\n",
  100 * mean(multicard_cases$nonzero_card_proration_count > 0L)
))
