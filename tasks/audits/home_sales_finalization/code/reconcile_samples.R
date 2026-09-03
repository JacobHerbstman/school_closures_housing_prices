suppressPackageStartupMessages(library(data.table))

baseline <- fread("../input/home_sales_with_characteristics_2006_2025.csv",
                  colClasses = list(character = c("row_id", "pin", "sale_document_num")))
corrected <- fread("../input/corrected_home_sale_characteristics_2006_2025.csv",
                   colClasses = list(character = c("row_id", "pin", "sale_document_num")))
clean <- fread("../input/home_sales_2008_2018.csv",
               colClasses = list(character = c("row_id", "pin", "sale_document_num")))
geocoded <- fread("../input/geocoded_home_sales_2008_2018.csv",
                  colClasses = list(character = c("row_id", "pin", "sale_document_num")))
master <- fread("../input/geocoded_master_home_transactions_2006_2025.csv",
                colClasses = list(character = c("row_id", "pin", "sale_document_num")))
reference <- readRDS("../input/careful_characteristic_updates.rds")
followups <- readRDS("../output/class_followups.rds")

# Full-row/field comparisons, not a spot check of changed observations.
stopifnot(identical(baseline$row_id, corrected$row_id), identical(baseline$row_id, master$row_id),
          identical(corrected$row_id, reference$transactions$row_id),
          !anyDuplicated(baseline$row_id), !anyDuplicated(clean$row_id), !anyDuplicated(geocoded$row_id))
supported <- reference$field_map[supported == TRUE]
for (field in supported$baseline) {
  stopifnot(identical(as.character(corrected[[field]]), as.character(reference$transactions[[paste0("hie_", field)]])),
            identical(as.character(corrected[[paste0("original_", field)]]), as.character(baseline[[field]])))
}
for (field in setdiff(names(baseline), supported$baseline)) {
  stopifnot(identical(corrected[[field]], baseline[[field]]))
}
stopifnot(identical(corrected$hie_correction_eligible, reference$transactions$hie_correction_eligible),
          all(reference$source_membership$start_year <= reference$source_membership$sale_year),
          all(reference$source_membership$last_active_year >= reference$source_membership$sale_year))

# The same explicit restrictions evaluated under four information sets separate
# physical corrections, class priority, and unresolved property-type conflicts.
evaluate_sample <- function(transactions, class_column) {
  property_class <- transactions[[class_column]]
  requirements <- list(
    study_period = transactions$sale_year %between% c(2008L, 2018L),
    county_sale_flags = !transactions$sale_filter_same_sale_within_365 &
      !transactions$sale_filter_less_than_10k & !transactions$sale_filter_deed_type,
    market_sale = is.finite(transactions$sale_price_nominal) & transactions$sale_price_nominal > 10000 &
      !is.na(transactions$sale_type) & transactions$sale_type != "LAND",
    single_card = transactions$single_improvement_card,
    resolved_non_mixed_class = property_class %in% c(202:211, 234, 278, 295),
    core_hedonics = is.finite(transactions$res_char_yrblt) &
      is.finite(transactions$res_char_bldg_sf) & transactions$res_char_bldg_sf > 0 &
      is.finite(transactions$res_char_land_sf) & transactions$res_char_land_sf > 0 &
      is.finite(transactions$res_char_beds) & is.finite(transactions$res_char_rooms) &
      is.finite(transactions$res_char_fbath) &
      !is.na(transactions$res_char_type_resd) & nzchar(trimws(transactions$res_char_type_resd)) &
      !is.na(transactions$res_char_cnst_qlty) & nzchar(trimws(transactions$res_char_cnst_qlty)) &
      !is.na(transactions$res_char_repair_cnd) & nzchar(trimws(transactions$res_char_repair_cnd)),
    apartment_count = property_class != 211L | transactions$res_char_apts %in% c("Two", "Three", "Four", "Five", "Six"),
    rooms_beds_integrity = transactions$res_char_rooms >= transactions$res_char_beds,
    price_per_sqft = transactions$sale_price_nominal / transactions$res_char_bldg_sf <= 5000
  )
  included <- rep(TRUE, nrow(transactions))
  reason <- rep("included", nrow(transactions))
  funnel <- vector("list", length(requirements))
  for (i in seq_along(requirements)) {
    passes <- !is.na(requirements[[i]]) & requirements[[i]]
    reason[included & !passes] <- names(requirements)[i]
    included <- included & passes
    funnel[[i]] <- data.table(step = names(requirements)[i], retained = sum(included))
  }
  list(included = included, reason = reason, funnel = rbindlist(funnel))
}
old <- evaluate_sample(baseline, "property_class")
physical_only <- evaluate_sample(corrected, "property_class")
updated_class <- evaluate_sample(corrected, "res_class")
final <- evaluate_sample(corrected, "analysis_class")
stopifnot(sum(old$included) == 167977L,
          setequal(corrected$row_id[final$included], clean$row_id))
variants <- data.table(
  version = c("Previous sample", "HIE fields with stale sale class", "Updated class before conflict screen", "Final coherent sample"),
  sales = c(sum(old$included), sum(physical_only$included), sum(updated_class$included), sum(final$included))
)
funnel <- merge(old$funnel, final$funnel, by = "step", suffixes = c("_old", "_new"), sort = FALSE)
funnel <- funnel[match(old$funnel$step, step)]

status <- corrected[, .(row_id, pin, sale_date, sale_year, sale_month, township_code, neighborhood_code,
                        property_class, original_res_class, res_class, analysis_class, analysis_property_type,
                        original_res_char_apts, res_char_apts, original_res_char_use, res_char_use,
                        sale_price_nominal, original_res_char_bldg_sf, res_char_bldg_sf,
                        property_type_conflict, hie_correction_eligible, hie_unresolved_fields,
                        hie_exemption_ids, hie_start_year_timing_uncertain)]
status[, `:=`(old_included = old$included, new_included = final$included,
               old_reason = old$reason, new_reason = final$reason,
               physical_only_included = physical_only$included, updated_class_included = updated_class$included)]
status[, membership := fcase(old_included & new_included, "retained",
                             old_included, "removed", new_included, "added", default = "neither")]
status[, exclusion_detail := fcase(
  new_reason == "resolved_non_mixed_class" & property_type_conflict, "conflicting_class_use_or_apartments",
  new_reason == "resolved_non_mixed_class" & is.na(res_class), "missing_updated_class",
  new_reason == "resolved_non_mixed_class" & res_class %in% 212L, "updated_mixed_use",
  default = new_reason
)]
changes <- status[membership %in% c("removed", "added")]
change_reasons <- changes[, .N, by = .(membership, exclusion_detail, old_reason)]
class_transitions <- status[old_included | new_included, .N,
                            by = .(original_res_class, res_class, analysis_property_type, membership)]
conversions <- status[property_class == 211L & analysis_property_type %in% "single_family" & new_included == TRUE]

old_sales <- baseline[old$included, .(row_id, sale_date, sale_year, sale_month, township_code, neighborhood_code,
                                     sale_price_nominal, res_char_bldg_sf,
                                     group = fifelse(property_class == 211L, "two_to_six_units", "single_family"))]
new_sales <- corrected[final$included, .(row_id, sale_date, sale_year, sale_month, township_code, neighborhood_code,
                                        sale_price_nominal, res_char_bldg_sf, group = analysis_property_type)]
samples <- rbindlist(list(old = old_sales, new = new_sales), idcol = "version")
samples[, `:=`(sale_price_nominal = as.numeric(sale_price_nominal), res_char_bldg_sf = as.numeric(res_char_bldg_sf))]
samples[, `:=`(price_per_sqft = sale_price_nominal / res_char_bldg_sf,
                month = as.IDate(sprintf("%d-%02d-01", sale_year, sale_month)))]
monthly <- samples[, .(sales = .N, median_price = median(sale_price_nominal),
                       median_sqft = median(res_char_bldg_sf), median_ppsf = median(price_per_sqft),
                       multifamily_share = mean(group == "two_to_six_units")), by = .(version, month)]
annual <- samples[, .(sales = .N, median_price = median(sale_price_nominal), median_ppsf = median(price_per_sqft),
                      multifamily_share = mean(group == "two_to_six_units")), by = .(version, sale_year)]
neighborhoods <- samples[, .(sales = .N, median_price = median(sale_price_nominal)),
                         by = .(version, township_code, neighborhood_code)]
distribution <- samples[, .(sales = .N, median_price = median(sale_price_nominal),
                            median_sqft = median(res_char_bldg_sf), median_ppsf = median(price_per_sqft),
                            p01_ppsf = quantile(price_per_sqft, .01), p99_ppsf = quantile(price_per_sqft, .99),
                            min_ppsf = min(price_per_sqft), max_ppsf = max(price_per_sqft),
                            below_5_ppsf = sum(price_per_sqft < 5), over_2000_ppsf = sum(price_per_sqft > 2000)),
                         by = .(version, group)]
monthly_wide <- merge(monthly[version == "old"], monthly[version == "new"], by = "month", suffixes = c("_old", "_new"))
trend_checks <- data.table(
  statistic = c("Monthly median price correlation", "Monthly median PPSF correlation",
                "Largest absolute monthly median price change, percent", "Largest monthly multifamily-share change, percentage points"),
  value = c(cor(monthly_wide$median_price_old, monthly_wide$median_price_new),
            cor(monthly_wide$median_ppsf_old, monthly_wide$median_ppsf_new),
            max(abs(monthly_wide$median_price_new / monthly_wide$median_price_old - 1)) * 100,
            max(abs(monthly_wide$multifamily_share_new - monthly_wide$multifamily_share_old)) * 100)
)
neighborhood_changes <- merge(neighborhoods[version == "old"], neighborhoods[version == "new"],
                              by = c("township_code", "neighborhood_code"), all = TRUE, suffixes = c("_old", "_new"))
neighborhood_changes[, `:=`(net_sales = sales_new - sales_old, share_change_pct = 100 * (sales_new / sales_old - 1))]
setorder(neighborhood_changes, share_change_pct)

# Later single-card records can corroborate, but cannot prove, a conversion at
# the sale date. Report missing follow-up and disagreement rather than patching.
later <- copy(followups$records)
later[, record_count := .N, by = .(pin, year)]
later <- later[record_count == 1L & as.integer(pin_num_cards) == 1L & tolower(pin_is_multicard) == "false"]
stopifnot(!anyDuplicated(later[, .(pin, year)]))
later[, later_group := fcase(class %in% c(202:210, 234, 278, 295), "single_family",
                             class %in% 211L, "two_to_six_units", class %in% 212L, "mixed_use",
                             default = "other_or_missing")]
later <- later[, .(pin, check_year = year, later_class = class, later_group,
                   later_apts = char_apts, later_use = char_use, followup_found = TRUE)]
class_review <- merge(followups$review, later, by = c("pin", "check_year"), all.x = TRUE, sort = FALSE)
stopifnot(nrow(class_review) == nrow(followups$review), !anyDuplicated(class_review$row_id))
class_review[, `:=`(group_agrees = corrected_group == later_group,
                    class_agrees = res_class == later_class,
                    apartments_agree = res_char_apts == later_apts,
                    use_agrees = res_char_use == later_use)]
class_review[, coherent_conversion := original_group == "two_to_six_units" & corrected_group == "single_family" &
               !property_type_conflict]
class_review[, selected_price_sample := row_id %in% clean$row_id]
class_validation <- class_review[, .(reviewed_sales = .N, matched_sales = sum(followup_found, na.rm = TRUE),
                                     group_agrees = sum(group_agrees, na.rm = TRUE),
                                     exact_class_agrees = sum(class_agrees, na.rm = TRUE),
                                     apartments_agree = sum(apartments_agree, na.rm = TRUE),
                                     use_agrees = sum(use_agrees, na.rm = TRUE)),
                                  by = .(coherent_conversion, property_type_conflict)]

# Complete coordinate keys are distinct from complete coordinate values.
# Validate the full master, not only the selected analysis rows.
keys <- unique(master[, .(pin, sale_year, longitude, latitude, centroid_x_crs_3435, centroid_y_crs_3435,
                          has_historical_coordinates)])
stopifnot(!anyDuplicated(keys[, .(pin, sale_year)]), !anyNA(keys$has_historical_coordinates))
complete <- is.finite(keys$longitude) & is.finite(keys$latitude) &
  is.finite(keys$centroid_x_crs_3435) & is.finite(keys$centroid_y_crs_3435)
stopifnot(identical(complete, keys$has_historical_coordinates))
points <- sf::st_as_sf(keys[complete], coords = c("longitude", "latitude"), crs = 4326)
stopifnot(all(sf::st_is_valid(points)))
points <- sf::st_transform(points, 3435)
projected <- sf::st_coordinates(points)
projection_error_ft <- sqrt((projected[, 1] - keys$centroid_x_crs_3435[complete])^2 +
                             (projected[, 2] - keys$centroid_y_crs_3435[complete])^2)
stopifnot(max(projection_error_ft) < 1,
          setequal(geocoded$row_id, clean$row_id[clean$row_id %in% master[has_historical_coordinates == TRUE, row_id]]),
          all(geocoded$coordinate_source == "historical_exact_pin_year"))
clean_index <- match(geocoded$row_id, clean$row_id)
for (field in names(clean)) stopifnot(identical(geocoded[[field]], clean[[field]][clean_index]))
coordinate_summary <- data.table(
  dataset = c("Master transactions", "Unique master PIN-years", "Selected price sample"),
  rows = c(nrow(master), nrow(keys), nrow(clean)),
  complete_coordinates = c(sum(master$has_historical_coordinates), sum(complete), nrow(geocoded))
)
coordinate_missing <- master[has_historical_coordinates == FALSE,
                             .(row_id, pin, sale_year, sale_price_nominal)]

hashes <- data.table(
  file = c("baseline_characteristics", "corrected_characteristics", "clean_price_sample", "geocoded_price_sample", "geocoded_master"),
  sha256 = vapply(c("../input/home_sales_with_characteristics_2006_2025.csv",
                    "../input/corrected_home_sale_characteristics_2006_2025.csv", "../input/home_sales_2008_2018.csv",
                    "../input/geocoded_home_sales_2008_2018.csv", "../input/geocoded_master_home_transactions_2006_2025.csv"),
                  function(path) digest::digest(file = path, algo = "sha256"), character(1))
)
saveRDS(list(variants = variants, funnel = funnel, changes = changes, change_reasons = change_reasons,
             class_transitions = class_transitions, conversions = conversions, class_review = class_review,
             class_validation = class_validation, monthly = monthly, annual = annual,
             neighborhoods = neighborhood_changes, distribution = distribution, trend_checks = trend_checks,
             coordinate_summary = coordinate_summary, coordinate_missing = coordinate_missing,
             max_projection_error_ft = max(projection_error_ft), hashes = hashes,
             unresolved_master = corrected[!is.na(hie_unresolved_fields), .N],
             unresolved_retained = clean[!is.na(hie_unresolved_fields), .N],
             unchanged_transactions = status[membership == "retained", .N],
             class_conflicts = corrected[property_type_conflict == TRUE, .N, by = hie_correction_eligible],
             date_precision = clean[, .N, by = sale_date_precision]), "../output/sample_reconciliation.rds")
print(variants)
print(change_reasons)
print(class_validation)
print(coordinate_summary)
print(trend_checks)
