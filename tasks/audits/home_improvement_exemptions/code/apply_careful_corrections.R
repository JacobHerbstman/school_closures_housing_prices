suppressPackageStartupMessages(library(data.table))
source("load_ccao_reference.R")

reference <- readRDS("../output/characteristic_updates.rds")
linked <- readRDS("../output/linked_transactions.rds")
exemptions <- readRDS("../output/exemption_years.rds")$exemptions
transactions <- copy(reference$transactions)
updates <- copy(reference$field_updates)
supported <- reference$field_map[supported == TRUE]
eligible_ids <- transactions[hie_correction_eligible == TRUE, row_id]
stopifnot(!anyDuplicated(exemptions$exemption_id), !anyDuplicated(transactions$row_id),
          !anyDuplicated(updates[, .(row_id, baseline_column)]))

# Equal source measurements, upload date, and expiry identify an exact repeat.
# Source tax year is deliberately excluded; no original source row is deleted.
signature_columns <- c("pin", grep("^qu_", names(exemptions), value = TRUE), "hie_last_year_active")
exemptions[, signature_id := .GRP, by = signature_columns]

# Intentional one-to-many provenance, unique by (transaction, exemption).
# Only records already active in that sale year can contribute.
records <- merge(
  linked$transaction_exemptions[row_id %in% eligible_ids],
  exemptions[, c("exemption_id", "signature_id", grep("^qu_", names(exemptions), value = TRUE)), with = FALSE][, qu_upload_date := NULL],
  by = "exemption_id", all.x = TRUE, sort = FALSE
)
stopifnot(!anyNA(records$signature_id), !anyDuplicated(records[, .(row_id, exemption_id)]),
          all(records$start_year <= records$sale_year),
          all(records$last_active_year >= records$sale_year))
setorder(records, row_id, start_year, qu_upload_date, exemption_id)
# Retaining the latest occurrence leaves the reference's replacement ordering
# unchanged; additive fields count each distinct signature once per sale year.
records[, counted := !duplicated(records, by = c("row_id", "signature_id"), fromLast = TRUE)]
additive_columns <- supported[operation == "add", source]
totals <- records[counted == TRUE, lapply(.SD, sum), by = row_id, .SDcols = additive_columns]
record_counts <- records[, .(
  hie_counted_exemption_records = sum(counted),
  hie_repeated_exemption_records = sum(!counted)
), by = row_id]
stopifnot(!anyDuplicated(totals$row_id), setequal(totals$row_id, eligible_ids))

setnames(updates, c("proposed", "status", "changed"),
         c("reference_proposed", "reference_status", "reference_changed"))
updates[, `:=`(proposed = reference_proposed, status = reference_status,
              applied_source_value = annual_source_value,
              counted_exemption_ids = contributing_exemption_ids)]
for (i in which(supported$operation == "add")) {
  baseline_column <- supported$baseline[i]
  source_column <- supported$source[i]
  positions <- which(updates$baseline_column == baseline_column)
  total_index <- match(updates$row_id[positions], totals$row_id)
  increment <- totals[[source_column]][total_index]
  original <- as.numeric(updates$original[positions])
  proposed <- original + increment
  contributors <- records[counted == TRUE & get(source_column) != 0,
                          .(ids = paste(sort(exemption_id), collapse = ";")), by = row_id]
  set(updates, positions, "proposed", as.character(proposed))
  set(updates, positions, "applied_source_value", as.character(increment))
  set(updates, positions, "counted_exemption_ids", contributors$ids[match(updates$row_id[positions], contributors$row_id)])
  set(updates, positions, "status", fifelse(is.na(original), "withheld_missing_baseline",
                                          fifelse(proposed == original, "unchanged", "applied")))
}

# County bcnq-qi2z metadata groups legacy partial-attic codes 6--9 under 5.
# Keep annual_source_value and reference codes unchanged as source evidence.
metadata <- jsonlite::fromJSON("../input/legacy_improvement_metadata.json")
description <- metadata$columns$description[metadata$columns$fieldName == "type_resd"]
stopifnot(length(description) == 1L,
          grepl("All 1.5 - 1.9 story houses are coded as 5", description, fixed = TRUE))
dictionary <- as.data.table(ccao$vars_dict)
residence_label <- dictionary[var_name_athena == "char_type_resd" & var_code == "5", var_value]
stopifnot(length(residence_label) == 1L)
updates[, residence_code_harmonized := baseline_column == "res_char_type_resd" &
          annual_source_value %in% as.character(6:9) &
          reference_status == "withheld_unknown_replacement_code"]
updates[residence_code_harmonized == TRUE,
        `:=`(proposed = residence_label, applied_source_value = "5", status = "applied")]

# A withheld replacement means the updated value is unknown, not that the
# original value is still correct. Preserve originals, but expose uncertainty.
updates[startsWith(status, "withheld"),
        `:=`(proposed = NA_character_, status = sub("^withheld", "unresolved", status))]

# Logical integrity checks, not percentile or magnitude trimming.
numeric_positions <- which(updates$operation == "add")
numeric_values <- as.numeric(updates$proposed[numeric_positions])
area <- updates$baseline_column[numeric_positions] %in% c("res_char_bldg_sf", "res_char_land_sf")
invalid <- !is.na(numeric_values) & (!is.finite(numeric_values) | numeric_values < 0 |
             (area & numeric_values == 0) | (!area & numeric_values != floor(numeric_values)))
updates[numeric_positions[invalid], `:=`(proposed = NA_character_, status = "unresolved_invalid_numeric")]
room_counts <- dcast(updates[baseline_column %in% c("res_char_rooms", "res_char_beds")],
                     row_id ~ baseline_column, value.var = "proposed")
contradictions <- room_counts[as.numeric(res_char_beds) > as.numeric(res_char_rooms), row_id]
updates[row_id %in% contradictions & baseline_column %in% c("res_char_rooms", "res_char_beds"),
        `:=`(proposed = NA_character_, status = "unresolved_bedrooms_exceed_rooms")]
updates[, changed := (is.na(original) != is.na(proposed)) |
          (!is.na(original) & !is.na(proposed) & original != proposed)]
updates[!startsWith(status, "unresolved"), status := fifelse(changed, "applied", "unchanged")]
updates[, differs_from_reference := (is.na(reference_proposed) != is.na(proposed)) |
          (!is.na(reference_proposed) & !is.na(proposed) & reference_proposed != proposed)]

# Each field table is many transactions to the unchanged transaction key.
for (i in seq_len(nrow(supported))) {
  field <- updates[baseline_column == supported$baseline[i]]
  positions <- match(field$row_id, transactions$row_id)
  stopifnot(!anyNA(positions))
  proposed <- field$proposed
  original <- transactions[[supported$baseline[i]]]
  if (is.integer(original)) proposed <- as.integer(proposed)
  else if (is.numeric(original)) proposed <- as.numeric(proposed)
  stopifnot(identical(is.na(proposed), is.na(field$proposed)))
  set(transactions, positions, supported$audit_column[i], proposed)
}
transactions[, `:=`(
  hie_counted_exemption_records = NA_integer_, hie_repeated_exemption_records = NA_integer_,
  hie_residence_code_harmonized = row_id %in% updates[residence_code_harmonized == TRUE, row_id],
  hie_rooms_beds_unresolved = row_id %in% contradictions,
  hie_any_characteristic_changed = row_id %in% updates[changed == TRUE, row_id],
  hie_any_withheld_update = row_id %in% updates[startsWith(status, "unresolved"), row_id]
)]
transactions[record_counts, on = "row_id", `:=`(
  hie_counted_exemption_records = i.hie_counted_exemption_records,
  hie_repeated_exemption_records = i.hie_repeated_exemption_records
)]
saveRDS(list(transactions = transactions, field_updates = updates,
             field_map = reference$field_map,
             source_membership = records[, .(row_id, pin, sale_year, exemption_id,
                                             signature_id, start_year, last_active_year, counted)]),
        "../output/careful_characteristic_updates.rds")
cat(sprintf("Preserved %s transactions; harmonized %s residence codes; %s sales have repeated entries.\n",
            nrow(transactions), sum(transactions$hie_residence_code_harmonized),
            sum(transactions$hie_repeated_exemption_records > 0, na.rm = TRUE)))
print(updates[startsWith(status, "unresolved"), .(fields = .N, transactions = uniqueN(row_id)), by = status])
