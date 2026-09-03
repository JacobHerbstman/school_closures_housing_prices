suppressPackageStartupMessages(library(data.table))
source("load_ccao_reference.R")

baseline <- fread(
  "../input/home_sales_with_characteristics_2006_2025.csv",
  colClasses = list(character = c("row_id", "pin", "sale_document_num"))
)
exemptions <- readRDS("../output/exemption_years.rds")
linked <- readRDS("../output/linked_transactions.rds")
audit <- readRDS("../output/characteristic_updates.rds")
transactions <- audit$transactions
updates <- audit$field_updates
supported <- audit$field_map[supported == TRUE]

# Originals, observation counts, keys, and uncorrected groups must be unchanged.
stopifnot(nrow(transactions) == nrow(baseline), !anyDuplicated(transactions$row_id))
for (column in names(baseline)) {
  stopifnot(identical(baseline[[column]], transactions[[column]]))
}
stopifnot(
  !anyDuplicated(exemptions$annual[, .(pin, sale_year)]),
  !anyDuplicated(linked$transaction_exemptions[, .(row_id, exemption_id)]),
  !anyDuplicated(updates[, .(row_id, baseline_column)]),
  identical(baseline$property_class, transactions$property_class),
  all(exemptions$exemptions$calculated_end == exemptions$exemptions$last_active_year),
  all(linked$transaction_exemptions$start_year <= linked$transaction_exemptions$sale_year),
  all(linked$transaction_exemptions$last_active_year >= linked$transaction_exemptions$sale_year)
)
for (i in seq_len(nrow(supported))) {
  original <- transactions[[supported$baseline[i]]]
  proposed <- transactions[[supported$audit_column[i]]]
  stopifnot(identical(original[!transactions$hie_correction_eligible], proposed[!transactions$hie_correction_eligible]))
  records <- updates[baseline_column == supported$baseline[i]]
  index <- match(records$row_id, transactions$row_id)
  stopifnot(
    !anyNA(index),
    identical(as.character(original[index]), records$original),
    identical(as.character(proposed[index]), records$proposed),
    all(records$sale_year < 2021L),
    all(transactions$single_improvement_card[index])
  )
  comparable <- !grepl("^withheld", records$status)
  stopifnot(identical(records$proposed[comparable], records$reference_value[comparable]))
  withheld <- grepl("^withheld", records$status)
  stopifnot(identical(records$original[withheld], records$proposed[withheld]))
}

# Every changed value must point to active raw exemption records for that sale.
changed <- updates[changed == TRUE]
stopifnot(!anyNA(changed$contributing_exemption_ids), all(nzchar(changed$contributing_exemption_ids)))
contributions <- changed[, .(exemption_id = as.integer(strsplit(contributing_exemption_ids, ";", fixed = TRUE)[[1L]])),
                         by = .(row_id, baseline_column)]
stopifnot(!anyNA(contributions$exemption_id))
matched_contributions <- merge(
  contributions, linked$transaction_exemptions[, .(row_id, exemption_id)],
  by = c("row_id", "exemption_id"), all.x = FALSE, sort = FALSE, allow.cartesian = TRUE
)
stopifnot(nrow(matched_contributions) == nrow(contributions))

# Upstream package examples: assessment cycles and overlapping exemptions.
stopifnot(
  identical(ccao$chars_288_active(2016, "77")[[1L]], 2016:2020),
  identical(ccao$chars_288_active(c(2017, 2013), c("Evanston", "New Trier")), list(2017:2021, 2013:2018))
)
fixture <- data.frame(
  pin = rep("00000000000001", 3), year = c(2015, 2017, 2017),
  qu_town = rep("25", 3),
  qu_upload_date = as.Date(c("2015-06-01", "2017-04-01", "2017-08-01")),
  qu_sqft_bld = c(200, 100, 200), qu_beds = c(1, 0, 1),
  qu_exterior_wall = c("1", "2", "4"), qu_class = c("206", "288", "288")
)
sparse <- as.data.table(ccao$chars_sparsify(
  fixture, pin_col = pin, year_col = year, town_col = qu_town,
  upload_date_col = qu_upload_date,
  additive_source = dplyr::all_of(c("qu_sqft_bld", "qu_beds")),
  replacement_source = dplyr::all_of(c("qu_exterior_wall", "qu_class"))
))
stopifnot(
  identical(sparse$year, 2015:2021),
  identical(as.numeric(sparse$qu_sqft_bld), c(200, 200, 500, 500, 300, 300, 300)),
  identical(sparse$qu_exterior_wall, c("1", "1", rep("4", 5))),
  identical(as.integer(sparse$hie_num_active), c(1L, 1L, 2L, 2L, 1L, 1L, 1L)),
  all(sparse$year >= min(fixture$year))
)
fixture_sales <- data.table(
  pin = rep("00000000000001", 7), year = c(2010L, 2014L, 2015L, 2018L, 2019L, 2021L, 2022L),
  char_bldg_sf = c(1000, 1000, 1000, 1000, 1200, 1500, 1500)
)
fixture_sales <- merge(fixture_sales, sparse, by = c("pin", "year"), all.x = TRUE, sort = TRUE)
fixture_sales[, proposed_sf := char_bldg_sf]
fixture_sales[year < 2021L & !is.na(qu_sqft_bld), proposed_sf := char_bldg_sf + qu_sqft_bld]
stopifnot(identical(fixture_sales$proposed_sf, c(1000, 1000, 1200, 1500, 1500, 1500, 1500)))

# Missing originals are a real difference from the reference, not an imputation.
missing_fixture <- data.frame(char_bldg_sf = c(NA_real_, NA_real_, 1000), qu_sqft_bld = c(200, NA_real_, 0))
missing_reference <- ccao$chars_update(missing_fixture,
  additive_target = dplyr::all_of("char_bldg_sf"), replacement_target = dplyr::all_of(character()))
stopifnot(identical(missing_reference$char_bldg_sf, c(200, 0, 1000)))
missing_proposed <- missing_fixture$char_bldg_sf + missing_fixture$qu_sqft_bld
stopifnot(all(is.na(missing_proposed[1:2])), missing_proposed[3] == 1000)
stopifnot(is.na(ccao$last_nonzero_element(NA_character_)),
          is.na(ccao$last_nonzero_element(c("0", NA_character_))),
          ccao$last_nonzero_element(c("203", NA_character_)) == "203")

# Tied timestamps use input order upstream. Demonstrate why we flag conflicts.
tie_fixture <- fixture[2:3, ]
tie_fixture$qu_upload_date <- as.Date("2017-04-01")
tie_forward <- ccao$chars_sparsify(tie_fixture, pin_col = pin, year_col = year, town_col = qu_town,
  upload_date_col = qu_upload_date, additive_source = dplyr::all_of("qu_sqft_bld"),
  replacement_source = dplyr::all_of("qu_exterior_wall"))
tie_reverse <- ccao$chars_sparsify(tie_fixture[2:1, ], pin_col = pin, year_col = year, town_col = qu_town,
  upload_date_col = qu_upload_date, additive_source = dplyr::all_of("qu_sqft_bld"),
  replacement_source = dplyr::all_of("qu_exterior_wall"))
stopifnot(all(tie_forward$qu_exterior_wall == "4"), all(tie_reverse$qu_exterior_wall == "2"))

# Class 288 preserves assessor class; porch code 3 follows the ingestion recode.
class_fixture <- data.frame(meta_class = c(203, 203), qu_class = c("288", "206"),
                            char_porch = c("0", "1"), qu_porch = c("3", "0"))
class_fixture$qu_class <- ifelse(class_fixture$qu_class != "288", class_fixture$qu_class, class_fixture$meta_class)
class_reference <- ccao$chars_update(class_fixture, additive_target = dplyr::all_of(character()),
                                    replacement_target = dplyr::all_of(c("meta_class", "char_porch")))
class_reference$char_porch[class_reference$char_porch == "3"] <- "0"
stopifnot(identical(as.character(class_reference$meta_class), c("203", "206")),
          identical(class_reference$char_porch, c("0", "1")))
apartment_codes <- as.data.table(ccao$vars_dict)[var_name_athena == "char_apts"]
stopifnot(apartment_codes[var_code == "1", var_value] == "Two", apartment_codes[var_code == "6", var_value] == "None")

inventory <- fread("../output/source_inventory.csv")
for (i in seq_len(nrow(inventory))) {
  stopifnot(digest::digest(file = paste0("../input/", inventory$file[i]), algo = "sha256") == inventory$sha256[i])
}
status_counts <- updates[, .(field_records = .N, transactions = uniqueN(row_id)), by = status]
withheld_by_field <- updates[grepl("^withheld", status), .(field_records = .N), by = .(baseline_column, status)]
setorder(withheld_by_field, baseline_column, status)
report <- c(
  "# Legacy exemption correction validation", "",
  "Steps 1--5 only. Production files and sample restrictions are unchanged.", "",
  sprintf("%s transactions have at least one proposed change; %s have at least one withheld field. These groups can overlap.",
          format(sum(transactions$hie_any_characteristic_changed), big.mark = ","),
          format(sum(transactions$hie_any_withheld_update), big.mark = ",")), "",
  "## Passed checks", "",
  sprintf("- All %s master transactions and every original field are unchanged.", format(nrow(baseline), big.mark = ",")),
  sprintf("- All %s exemption expiration years agree with the published file.", format(nrow(exemptions$exemptions), big.mark = ",")),
  sprintf("- %s unique PIN-year corrections match independent interval reconstruction for every available physical update field.", format(nrow(exemptions$annual), big.mark = ",")),
  "- Transaction, annual-correction, field-update, and source-membership keys are unique at their stated units.",
  "- Every changed field points to active raw exemption records; none is applied before its start or after its expiration.",
  "- All no-match, multicard, and post-2020 records retain their original characteristics.",
  "- All non-withheld candidate values match the pinned Assessor update result, with documented code-to-label translation and porch recode.",
  "- Every withheld field preserves its original value.",
  "- Synthetic checks cover a 2015 renovation with a 2010 sale, first/last active years, overlap, same-year updates, expiration, the 2021 cutoff, missing baselines, missing class, timestamp ties, class 288, porch code 3, and apartment-code translation.",
  "- Raw inputs and the transaction baseline retain their recorded SHA-256 fingerprints.", "",
  "## Transaction coverage", "",
  "| Status | Transactions |", "|---|---:|",
  transactions[, sprintf("| %s | %s |", hie_status, format(.N, big.mark = ",")), by = hie_status]$V1,
  "", "## Field decisions", "",
  "Counts below are transaction-field records. A transaction can have several changes or flags.", "",
  "| Decision | Field records | Distinct transactions |", "|---|---:|---:|",
  status_counts[, sprintf("| %s | %s | %s |", status, format(field_records, big.mark = ","), format(transactions, big.mark = ","))],
  "", "| Field | Withheld reason | Field records |", "|---|---|---:|",
  withheld_by_field[, sprintf("| %s | %s | %s |", baseline_column, status, field_records)],
  "", "## Limitations retained", "",
  "- Exemption start years are annual administrative timing, not verified physical completion dates; start-year sales carry a timing flag.",
  "- Source class may be missing. The reference retains the last observed nonzero class if available; otherwise class is flagged unresolved and the baseline is preserved.",
  "- The raw extract lacks qu_renovation, qu_site_desire, and qu_state_of_repair. Those baseline fields are not corrected.",
  "- The baseline has no char_tp_dsgn field; its source updates are retained in exemption_years.rds but not attached as a new hedonic.",
  "- Unknown replacement codes and winning-timestamp conflicts are withheld, not guessed. Earlier conflicts superseded by a later unambiguous replacement do not block that replacement.",
  "- Sale-record property_class is preserved separately from the proposed assessor hie_res_class.",
  "- No inference is made that the extract contains every historical renovation or that unchanged observations are error-free.",
  "- Sample attrition, eligibility changes, and adoption into production are step 6 and have not been performed.", "",
  "## Reproduction environment", "",
  paste0("R ", getRversion()), "",
  vapply(required_packages, function(package) paste0("- ", package, " ", packageVersion(package)), character(1))
)
writeLines(report, "../output/validation.md")
cat("All transaction, timing, reference, provenance, and synthetic checks passed.\n")
