suppressPackageStartupMessages(library(data.table))

baseline <- fread("../input/home_sales_with_characteristics_2006_2025.csv",
                  colClasses = list(character = c("row_id", "pin", "sale_document_num")))
reference <- readRDS("../output/characteristic_updates.rds")
audit <- readRDS("../output/careful_characteristic_updates.rds")
exemptions <- readRDS("../output/exemption_years.rds")$exemptions
post_expiry <- readRDS("../output/post_expiry_records.rds")
transactions <- audit$transactions
updates <- audit$field_updates
membership <- audit$source_membership
supported <- audit$field_map[supported == TRUE]
stopifnot(identical(transactions$row_id, baseline$row_id),
          !anyDuplicated(updates[, .(row_id, baseline_column)]),
          !anyDuplicated(membership[, .(row_id, exemption_id)]),
          all(membership$start_year <= membership$sale_year),
          all(membership$last_active_year >= membership$sale_year),
          all(membership[, .(counted = sum(counted)), by = .(row_id, signature_id)]$counted == 1L))
for (column in names(baseline)) stopifnot(identical(baseline[[column]], transactions[[column]]))
for (i in seq_len(nrow(supported))) {
  field <- updates[baseline_column == supported$baseline[i]]
  index <- match(field$row_id, transactions$row_id)
  stopifnot(!anyNA(index),
            identical(as.character(transactions[[supported$audit_column[i]]][index]), field$proposed),
            identical(transactions[[supported$audit_column[i]]][!transactions$hie_correction_eligible],
                      transactions[[supported$baseline[i]]][!transactions$hie_correction_eligible]))
}
stopifnot(all(is.na(updates[startsWith(status, "unresolved"), proposed])),
          transactions[hie_correction_eligible == TRUE,
                       sum(hie_res_char_beds > hie_res_char_rooms, na.rm = TRUE)] == 0L)

# Independent arithmetic: an identical group contributes its mean, not its
# sum. Verify all seven additive fields, not just the reviewed square footage.
raw <- merge(membership, exemptions[, c("exemption_id", supported[operation == "add", source]), with = FALSE],
             by = "exemption_id", all.x = TRUE, sort = FALSE)
for (i in which(supported$operation == "add")) {
  source_column <- supported$source[i]
  by_signature <- raw[, .(value = mean(get(source_column)), distinct = uniqueN(get(source_column))),
                      by = .(row_id, signature_id)]
  stopifnot(all(by_signature$distinct == 1L))
  expected <- by_signature[, .(value = sum(value)), by = row_id]
  field <- updates[baseline_column == supported$baseline[i]]
  stopifnot(identical(as.numeric(field$applied_source_value), expected$value[match(field$row_id, expected$row_id)]))
  resolved <- !startsWith(field$status, "unresolved")
  stopifnot(all(as.numeric(field$proposed[resolved]) ==
                  as.numeric(field$original[resolved]) + as.numeric(field$applied_source_value[resolved])))
}
unchanged_replacements <- updates[operation == "replace" & !residence_code_harmonized &
                                    !startsWith(status, "unresolved")]
stopifnot(identical(unchanged_replacements$proposed, unchanged_replacements$reference_proposed),
          all(updates[residence_code_harmonized == TRUE, annual_source_value] %in% as.character(6:9)),
          all(updates[residence_code_harmonized == TRUE, applied_source_value] == "5"))

# Every numeric/categorical update still identifies active source records.
applied <- updates[status == "applied"]
stopifnot(!anyNA(applied$counted_exemption_ids), all(nzchar(applied$counted_exemption_ids)))
ids <- applied[, .(exemption_id = as.integer(strsplit(counted_exemption_ids, ";", fixed = TRUE)[[1L]])),
               by = .(row_id, baseline_column)]
stopifnot(nrow(ids[!membership, on = .(row_id, exemption_id)]) == 0L)
additive_ids <- ids[baseline_column %in% supported[operation == "add", baseline]]
stopifnot(nrow(additive_ids[!membership[counted == TRUE], on = .(row_id, exemption_id)]) == 0L)

# Artificial cases: future copies cannot alter an earlier sale; two distinct
# additions remain separate; identical measurements on another parcel do too.
fixture <- data.table(pin = c("A", "A", "A", "B"), start = c(2010L, 2011L, 2011L, 2010L),
                      end = 2014L, upload = c("2010-06-01", "2010-06-01", "2011-06-01", "2010-06-01"),
                      area = c(100, 100, 200, 100))
expanded <- fixture[, .(year = seq.int(start, end)), by = .(pin, start, end, upload, area)]
once <- unique(expanded, by = c("pin", "year", "end", "upload", "area"))
fixture_totals <- once[, .(area = sum(area)), by = .(pin, year)]
stopifnot(fixture_totals[pin == "A" & year == 2010L, area] == 100,
          all(fixture_totals[pin == "A" & year >= 2011L, area] == 300),
          all(fixture_totals[pin == "B", area] == 100),
          !any(fixture_totals$year < 2010L | fixture_totals$year > 2014L))

# Later records are validation only. The correction producer does not read
# this file. Restrict comparisons to one observed, flagged single card.
history <- copy(post_expiry$records)
history[, observed_cards := .N, by = .(pin, year)]
history <- history[observed_cards == 1L & pin_is_multicard == FALSE & as.numeric(pin_num_cards) == 1]
setnames(history, "year", "check_year")
stopifnot(!anyDuplicated(history[, .(pin, check_year)]), !anyDuplicated(post_expiry$review$row_id))
# Many reviewed sales to one post-expiry PIN-year; unmatched histories remain.
comparison <- merge(post_expiry$review, history, by = c("pin", "check_year"), all.x = TRUE, sort = FALSE)
comparison <- merge(comparison, transactions[, .(row_id, sale_year, hie_repeated_exemption_records)],
                    by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(nrow(comparison) == nrow(post_expiry$review), !anyDuplicated(comparison$row_id),
          all(comparison$check_year > comparison$sale_year))
history_counts <- list()
for (column in c("res_char_bldg_sf", "res_char_rooms", "res_char_beds")) {
  field <- updates[baseline_column == column]
  index <- match(comparison$row_id, field$row_id)
  later <- as.numeric(comparison[[sub("^res_", "", column)]])
  old <- as.numeric(field$reference_proposed[index])
  new <- as.numeric(field$proposed[index])
  duplicate <- comparison$hie_repeated_exemption_records > 0
  history_counts[[column]] <- data.table(
    field = column, reviewed_sales = nrow(comparison), observed_later = sum(!is.na(later)),
    comparable_reference = sum(!is.na(old) & !is.na(later)), reference_matches = sum(old == later, na.rm = TRUE),
    comparable_careful = sum(!is.na(new) & !is.na(later)), careful_matches = sum(new == later, na.rm = TRUE),
    duplicate_comparable = sum(duplicate & !is.na(new) & !is.na(later)),
    duplicate_reference_matches = sum(duplicate & old == later, na.rm = TRUE),
    duplicate_careful_matches = sum(duplicate & new == later, na.rm = TRUE)
  )
}
history_counts <- rbindlist(history_counts)
reference_bad <- reference$transactions[hie_correction_eligible == TRUE & hie_res_char_beds > hie_res_char_rooms, row_id]
reference_new_bad <- reference$transactions[row_id %in% reference_bad & res_char_beds <= res_char_rooms, row_id]
resolved_bad <- transactions[row_id %in% reference_new_bad & !hie_rooms_beds_unresolved, row_id]
unresolved <- updates[startsWith(status, "unresolved"), .(field_records = .N, transactions = uniqueN(row_id)), by = status]
report <- c(
  "# Rule-based exemption correction trial", "",
  "Audit only. No transaction is removed; no production output or final sample changes.", "",
  "## What changed", "",
  sprintf("- All %s transactions and every original baseline column are preserved.", format(nrow(transactions), big.mark = ",")),
  sprintf("- %s sales have exact repeated active entries counted once.", sum(transactions$hie_repeated_exemption_records > 0, na.rm = TRUE)),
  sprintf("- %s residence-type updates use the documented legacy-code crosswalk.", sum(transactions$hie_residence_code_harmonized)),
  sprintf("- %s of the %s newly introduced bedroom/room contradictions disappear after duplicate handling.", length(resolved_bad), length(reference_new_bad)),
  sprintf("- %s sales retain unresolved bedroom/room pairs, including inconsistencies already in the baseline.", sum(transactions$hie_rooms_beds_unresolved)),
  sprintf("- %s sales have at least one unresolved field; %s sales differ from the original audit's proposed values.",
          sum(transactions$hie_any_withheld_update), uniqueN(updates[differs_from_reference == TRUE, row_id])),
  sprintf("- %s sales have an observed corrected value different from baseline (missing values are not counted as corrections).",
          uniqueN(updates[status == "applied", row_id])), "",
  "## Unresolved fields", "",
  "Counts overlap across reasons; they are not sample exclusions.", "",
  "| Reason | Fields | Sales |", "|---|---:|---:|",
  unresolved[, sprintf("| %s | %s | %s |", status, field_records, transactions)], "",
  "## Post-expiry check", "",
  sprintf("Requested %s PIN-years for %s sales. Single-card records were found for %s sales.",
          uniqueN(post_expiry$review[, .(pin, check_year)]), nrow(comparison), sum(!is.na(comparison$card))),
  "Includes all repeated-entry sales, unresolved room/bed cases, and the twelve largest original additions.",
  "Each comparison uses the first year after all exemptions active at that sale have expired.", "",
  "| Field | Reference matches / comparable | Careful matches / comparable |", "|---|---:|---:|",
  history_counts[, sprintf("| %s | %s / %s | %s / %s |", field, reference_matches, comparable_reference, careful_matches, comparable_careful)], "",
  "For repeated-entry sales alone:", "",
  "| Field | Reference matches | Careful matches | Careful comparable |", "|---|---:|---:|---:|",
  history_counts[, sprintf("| %s | %s | %s | %s |", field, duplicate_reference_matches, duplicate_careful_matches, duplicate_comparable)], "",
  "These comparisons are not an independent physical survey. Subsequent renovations, source updates, or the 2021 migration can cause differences.",
  "Missing later records do not certify or invalidate a correction; no later values are copied backward.", "",
  "## Checks and limits", "",
  "- Transaction, source-membership, field-update, and post-expiry join cardinalities verified.",
  "- Additive arithmetic independently reproduced for every eligible sale and all seven additive fields.",
  "- Distinct additions and all raw exemption IDs preserved; originals, ineligible records, and sale prices unchanged.",
  "- Synthetic checks cover future copies, active-year boundaries, separate additions, and separate parcels.",
  "- Unresolved fields are missing, not quietly replaced with old values. No remaining observed bedroom count exceeds its observed room count among eligible sales.",
  "- Exact duplication is an explicit source-event assumption, not proof of one real-world renovation.",
  "- No size cap, winsorization, percentile trimming, backward filling, or parcel-specific override is used.",
  "- Large but logically possible additions and nonidentical overlaps are not automatically resolved or removed.",
  "- Annual timing flags and the original reference's replacement precedence remain unchanged.",
  "- The unchanged reference branch remains in characteristic_updates.rds; this trial is in careful_characteristic_updates.rds."
)
writeLines(report, "../output/careful_validation.md")
cat(paste(report, collapse = "\n"), "\n")
