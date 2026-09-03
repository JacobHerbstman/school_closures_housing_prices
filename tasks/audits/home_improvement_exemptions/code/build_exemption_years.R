suppressPackageStartupMessages(library(data.table))
source("load_ccao_reference.R")

exemptions <- as.data.table(arrow::read_parquet("../input/hie_data.parquet"))
exemptions[, `:=`(
  exemption_id = .I,
  start_year = as.integer(year),
  last_active_year = as.integer(hie_last_year_active)
)]
field_map <- rbindlist(list(
  data.table(operation = "add", source = ccao$chars_cols$add$source, target = ccao$chars_cols$add$target),
  data.table(operation = "replace", source = ccao$chars_cols$replace$source, target = ccao$chars_cols$replace$target)
))
field_map[, source_available := source %in% names(exemptions)]
additive_columns <- field_map[operation == "add" & source_available, source]
replacement_columns <- field_map[operation == "replace" & source_available, source]
update_columns <- c(additive_columns, replacement_columns)
stopifnot(
  !anyNA(exemptions[, c("pin", "start_year", "last_active_year", "qu_town", "qu_upload_date", setdiff(update_columns, "qu_class")), with = FALSE]),
  all(exemptions$qu_town %in% ccao$town_dict$township_code),
  all(exemptions$start_year <= exemptions$last_active_year),
  !anyDuplicated(exemptions$exemption_id),
  !anyDuplicated(field_map$source),
  !anyDuplicated(field_map$target),
  all(exemptions[, uniqueN(qu_town), by = .(pin, start_year)]$V1 == 1L)
)

# One row per start-year/township; the lookup is many exemptions to one schedule.
schedules <- unique(exemptions[, .(start_year, qu_town)])
schedules[, calculated_end := vapply(ccao$chars_288_active(start_year, qu_town), max, numeric(1))]
exemptions <- merge(exemptions, schedules, by = c("start_year", "qu_town"), all.x = TRUE, sort = FALSE)
setorder(exemptions, exemption_id)
stopifnot(all(exemptions$calculated_end == exemptions$last_active_year))

# Reproduce the pinned Assessor implementation, without restricting the source
# to the study period: earlier exemptions can still be active in a sale year.
# Only class has missing source values. The reference propagates missing class
# if a group has no observed nonzero class; physical fields are fully observed.
annual <- as.data.table(ccao$chars_sparsify(
  as.data.frame(exemptions), pin_col = pin, year_col = year, town_col = qu_town,
  upload_date_col = qu_upload_date,
  additive_source = dplyr::all_of(additive_columns),
  replacement_source = dplyr::all_of(replacement_columns)
))
setnames(annual, "year", "sale_year")
annual[, sale_year := as.integer(sale_year)]
setorder(annual, pin, sale_year)
stopifnot(!anyDuplicated(annual[, .(pin, sale_year)]))

# Independently expand the published inclusive intervals. Each membership row
# identifies the exact raw exemption contributing to a PIN-year correction.
membership <- exemptions[, .(sale_year = seq.int(start_year, last_active_year)), by = .(exemption_id, pin)]
expanded <- merge(membership, exemptions[, c("exemption_id", "start_year", "qu_upload_date", update_columns), with = FALSE],
                  by = "exemption_id", all.x = TRUE, sort = FALSE)
setorder(expanded, pin, sale_year, start_year, qu_upload_date, exemption_id)
expected <- expanded[, lapply(.SD, sum), by = .(pin, sale_year), .SDcols = additive_columns]
for (column in replacement_columns) {
  observed <- expanded[!is.na(get(column)) & as.character(get(column)) != "0",
                       .(pin, sale_year, value = as.character(get(column)))]
  replacement <- observed[!duplicated(observed, by = c("pin", "sale_year"), fromLast = TRUE)]
  missing_keys <- unique(expanded[is.na(get(column)), .(pin, sale_year)])
  set(expected, j = column, value = rep("0", nrow(expected)))
  expected[missing_keys, on = .(pin, sale_year), (column) := NA_character_]
  expected[replacement, on = .(pin, sale_year), (column) := i.value]
}
setorder(expected, pin, sale_year)
stopifnot(identical(expected[, .(pin, sale_year)], annual[, .(pin, sale_year)]))
for (column in update_columns) {
  stopifnot(identical(as.character(expected[[column]]), as.character(annual[[column]])))
}

# Same-timestamp contradictory replacements have no defensible temporal order.
# The reference uses source order for ties; retain its result but flag the tie.
replacement_conflicts <- rbindlist(lapply(replacement_columns, function(column) {
  exemptions[get(column) != "0", .(
    different_values = uniqueN(get(column)),
    exemption_ids = paste(exemption_id, collapse = ";")
  ), by = .(pin, start_year, qu_upload_date)][different_values > 1L][, source := column]
}), fill = TRUE)
provenance <- expanded[, .(
  exemption_ids = paste(exemption_id, collapse = ";"),
  exemption_record_count = .N,
  active_start_years = uniqueN(start_year),
  exemption_starts_this_year = any(start_year == sale_year),
  class_source_missing = anyNA(qu_class)
), by = .(pin, sale_year)]
annual <- merge(annual, provenance, by = c("pin", "sale_year"), all.x = TRUE, sort = FALSE)
stopifnot(all(annual$hie_num_active == annual$active_start_years))
setorder(annual, pin, sale_year)
setorder(membership, pin, sale_year, exemption_id)

saveRDS(list(
  annual = annual, membership = membership, exemptions = exemptions,
  field_map = field_map, replacement_conflicts = replacement_conflicts
), "../output/exemption_years.rds")
cat(sprintf("Verified %s exemption expirations and %s unique PIN-year corrections.\n", nrow(exemptions), nrow(annual)))
cat(sprintf("Every available update field matches independent interval reconstruction; %s tied replacement conflicts.\n", nrow(replacement_conflicts)))
cat(sprintf("Missing class appears in %s PIN-years; %s have no resolved class update.\n", sum(annual$class_source_missing), sum(is.na(annual$qu_class))))
