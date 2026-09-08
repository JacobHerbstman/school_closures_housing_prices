suppressPackageStartupMessages(library(data.table))

transactions <- fread("../input/home_sales_with_characteristics_2006_2025.csv",
                      colClasses = list(character = c("row_id", "pin", "sale_document_num")))
exemptions <- as.data.table(arrow::read_parquet("../input/hie_data.parquet"))
stopifnot(!anyDuplicated(transactions$row_id), nrow(transactions) > 0L,
          digest::digest(file = "../input/hie_data.parquet", algo = "sha256") ==
            "2ab0c8d234a99bb9bec5c1da52d9d3fef33d8e20b8337c56c12623062c20e006",
          digest::digest(file = "../input/ccao.zip", algo = "sha256") ==
            "1aa324332c11065e1080aca12365731ce6884de039032f4cb09df290600bbfb2")

# Read the Assessor's field map and labels, not its executable valuation code.
archive <- unzip("../input/ccao.zip", list = TRUE)
ccao <- new.env()
for (name in c("chars_cols", "vars_dict")) {
  member <- archive[endsWith(archive$Name, paste0("/data/", name, ".rda")), ]
  stopifnot(nrow(member) == 1L)
  connection <- unz("../input/ccao.zip", member$Name, open = "rb")
  decoded <- rawConnection(memDecompress(readBin(connection, "raw", member$Length), "bzip2"))
  load(decoded, envir = ccao)
  close(connection)
  close(decoded)
}
field_map <- rbindlist(list(
  data.table(operation = "add", source = ccao$chars_cols$add$source, target = ccao$chars_cols$add$target),
  data.table(operation = "replace", source = ccao$chars_cols$replace$source, target = ccao$chars_cols$replace$target)
))
field_map[, baseline := fifelse(target == "meta_class", "res_class", paste0("res_", target))]
field_map <- field_map[source %in% names(exemptions) & baseline %in% names(transactions)]
dictionary <- as.data.table(ccao$vars_dict)
metadata <- jsonlite::fromJSON("../input/legacy_improvement_metadata.json")
description <- metadata$columns$description[metadata$columns$fieldName == "type_resd"]
stopifnot(length(description) == 1L,
          grepl("All 1.5 - 1.9 story houses are coded as 5", description, fixed = TRUE),
          nrow(field_map) == 27L, !anyDuplicated(field_map$baseline),
          !anyNA(exemptions[, c("pin", "year", "hie_last_year_active", "qu_upload_date",
                               setdiff(field_map$source, "qu_class")), with = FALSE]))

# Exemptions apply through the published last active year, including that year.
# Raw row numbers identify exemptions within the checksum-verified source file.
exemptions[, `:=`(exemption_id = .I, start_year = as.integer(year),
                  last_active_year = as.integer(hie_last_year_active))]
stopifnot(all(exemptions$start_year <= exemptions$last_active_year))
signature_columns <- c("pin", grep("^qu_", names(exemptions), value = TRUE), "hie_last_year_active")
exemptions[, signature_id := .GRP, by = signature_columns]
membership <- exemptions[, .(sale_year = seq.int(start_year, last_active_year)),
                          by = .(pin, exemption_id)]
stopifnot(!anyDuplicated(membership[, .(pin, sale_year, exemption_id)]))

# Intentional many-to-many PIN-year join: one row per transaction/exemption.
# Only this provenance table expands; the transaction table never loses rows.
records <- merge(transactions[, .(row_id, pin, sale_year)], membership,
                 by = c("pin", "sale_year"), allow.cartesian = TRUE, sort = FALSE)
records <- merge(records, exemptions[, c("exemption_id", "signature_id", "start_year",
                                         "last_active_year", "qu_upload_date", field_map$source), with = FALSE],
                 by = "exemption_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyDuplicated(records[, .(row_id, exemption_id)]), !anyNA(records$start_year),
          all(records$start_year <= records$sale_year), all(records$last_active_year >= records$sale_year))
setorder(records, row_id, start_year, qu_upload_date, exemption_id)
records[, counted := !duplicated(records, by = c("row_id", "signature_id"), fromLast = TRUE)]
provenance <- records[, .(
  hie_exemption_ids = paste(exemption_id, collapse = ";"),
  hie_counted_exemption_ids = paste(exemption_id[counted], collapse = ";"),
  hie_repeated_exemption_records = sum(!counted),
  hie_start_year_timing_uncertain = any(start_year == sale_year)
), by = row_id]
stopifnot(!anyDuplicated(provenance$row_id))
positions <- match(transactions$row_id, provenance$row_id)
transactions[, `:=`(
  hie_source_active = !is.na(positions),
  hie_correction_eligible = !is.na(positions) & single_improvement_card & sale_year < 2021L,
  hie_exemption_ids = provenance$hie_exemption_ids[positions],
  hie_counted_exemption_ids = provenance$hie_counted_exemption_ids[positions],
  hie_repeated_exemption_records = provenance$hie_repeated_exemption_records[positions],
  hie_start_year_timing_uncertain = !is.na(positions) & provenance$hie_start_year_timing_uncertain[positions]
)]
transactions[, hie_status := fcase(
  !hie_source_active, "no_active_legacy_exemption",
  sale_year >= 2021L, "already_in_post2020_source",
  !single_improvement_card, "not_single_card",
  default = "eligible_pre2021_single_card"
)]
eligible <- which(transactions$hie_correction_eligible)
stopifnot(all(transactions$res_pin_num_cards[eligible] == 1L),
          all(transactions$res_pin_is_multicard[eligible] == FALSE))
records <- records[row_id %in% transactions$row_id[eligible]]
updates <- vector("list", nrow(field_map))

for (i in seq_len(nrow(field_map))) {
  source_column <- field_map$source[i]
  baseline_column <- field_map$baseline[i]
  target <- field_map$target[i]
  original <- transactions[[baseline_column]][eligible]
  proposed <- original
  status <- rep("observed", length(eligible))
  set(transactions, j = paste0("original_", baseline_column), value = copy(transactions[[baseline_column]]))

  if (field_map$operation[i] == "add") {
    totals <- records[counted == TRUE, .(increment = sum(get(source_column))), by = row_id]
    index <- match(transactions$row_id[eligible], totals$row_id)
    stopifnot(!anyNA(index), !anyDuplicated(totals$row_id))
    proposed <- original + totals$increment[index]
    status[is.na(original)] <- "missing_baseline"
    area <- baseline_column %in% c("res_char_bldg_sf", "res_char_land_sf")
    invalid <- !is.na(proposed) & (!is.finite(proposed) | proposed < 0 |
                  (area & proposed == 0) | (!area & proposed != floor(proposed)))
    proposed[invalid] <- NA_real_
    status[invalid] <- "invalid_numeric"
  } else {
    # Latest nonzero replacement wins. Conflicting values with the same start
    # year and upload date have no defensible ordering and remain missing.
    candidates <- records[!is.na(get(source_column)) & as.character(get(source_column)) != "0"]
    latest <- candidates[!duplicated(row_id, fromLast = TRUE),
                         .(row_id, winning_start = start_year, winning_upload = qu_upload_date)]
    candidates <- merge(candidates, latest, by = "row_id", all.x = TRUE, sort = FALSE)
    latest <- candidates[start_year == winning_start & qu_upload_date == winning_upload,
                         .(value = as.character(tail(get(source_column), 1L)),
                           conflict = uniqueN(get(source_column)) > 1L), by = row_id]
    index <- match(transactions$row_id[eligible], latest$row_id)
    has_update <- !is.na(index)
    values <- latest$value[index]
    if (target == "meta_class") {
      # 288 denotes the exemption itself, not a new property class.
      has_update <- has_update & values != "288"
      missing_ids <- records[is.na(qu_class), unique(row_id)]
      missing_class <- transactions$row_id[eligible] %in% missing_ids & is.na(index)
      proposed[missing_class] <- NA_integer_
      status[missing_class] <- "missing_source_class"
    }
    if (target == "char_type_resd") values[values %in% as.character(6:9)] <- "5"
    if (target == "char_porch") values[values == "3" & !is.na(values)] <- "0"
    codes <- dictionary[var_name_athena == target & var_data_type == "categorical" & !is.na(var_code)]
    if (nrow(codes)) {
      stopifnot(!anyDuplicated(codes$var_code))
      decoded <- codes$var_value[match(values, codes$var_code)]
      proposed[has_update] <- decoded[has_update]
      status[has_update & is.na(decoded)] <- "unknown_replacement_code"
    } else {
      decoded <- as.numeric(values)
      stopifnot(!any(is.na(decoded) & !is.na(values)))
      proposed[has_update] <- decoded[has_update]
    }
    conflict <- !is.na(index) & latest$conflict[index]
    proposed[conflict] <- NA
    status[conflict] <- "tied_replacement"
  }
  if (is.integer(original)) proposed <- as.integer(proposed)
  set(transactions, eligible, baseline_column, proposed)
  updates[[i]] <- data.table(row_id = transactions$row_id[eligible], field = baseline_column, status = status)
}

# A contradictory room/bed pair does not identify which measurement is wrong.
contradictions <- eligible[transactions$res_char_beds[eligible] > transactions$res_char_rooms[eligible] &
                            !is.na(transactions$res_char_beds[eligible]) & !is.na(transactions$res_char_rooms[eligible])]
transactions[contradictions, `:=`(res_char_beds = NA_real_, res_char_rooms = NA_real_)]
updates <- rbindlist(updates)
updates[row_id %in% transactions$row_id[contradictions] & field %in% c("res_char_beds", "res_char_rooms"),
        status := "bedrooms_exceed_rooms"]
unresolved <- updates[status != "observed", .(hie_unresolved_fields = paste(field, collapse = ";")), by = row_id]
transactions[, hie_unresolved_fields := unresolved$hie_unresolved_fields[match(row_id, unresolved$row_id)]]

# Use the corrected same-year improvement class throughout analysis. Do not
# revert to the sale-record class when the updated class is missing or conflicts
# with an observed use/apartment count. Class-size bands are not trimming rules.
transactions[, property_type_conflict :=
  (res_class %in% c(202:210, 234, 278, 295) &
     (res_char_apts %in% c("Two", "Three", "Four", "Five", "Six") | res_char_use %in% "Multi-Family")) |
  (res_class %in% 211L & (res_char_apts %in% "None" | res_char_use %in% "Single-Family"))]
transactions[, analysis_class := res_class]
transactions[property_type_conflict == TRUE, analysis_class := NA_integer_]
transactions[, analysis_property_type := fcase(
  analysis_class %in% c(202:210, 234, 278, 295), "single_family",
  analysis_class %in% 211L, "two_to_six_units",
  analysis_class %in% 212L, "mixed_use",
  default = NA_character_
)]
stopifnot(!anyDuplicated(transactions$row_id), !anyNA(transactions$property_type_conflict))
fwrite(transactions, "../output/corrected_home_sale_characteristics_2006_2025.csv", na = "NA")
cat(sprintf("Preserved %s transactions; corrected %s eligible sales; %s have unresolved HIE fields.\n",
            nrow(transactions), length(eligible), nrow(unresolved)))
print(transactions[, .N, by = hie_status])
print(transactions[property_type_conflict == TRUE, .N, by = hie_correction_eligible])
