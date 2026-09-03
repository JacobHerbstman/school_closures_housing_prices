suppressPackageStartupMessages(library(data.table))
source("load_ccao_reference.R")

linked_data <- readRDS("../output/linked_transactions.rds")
transactions <- linked_data$transactions
setDT(transactions)
exemption_data <- readRDS("../output/exemption_years.rds")
field_map <- copy(exemption_data$field_map)
field_map[, baseline := fifelse(target == "meta_class", "res_class", paste0("res_", target))]
field_map[, `:=`(
  audit_column = paste0("hie_", baseline),
  baseline_available = baseline %in% names(transactions)
)]
field_map[, supported := source_available & baseline_available]
supported <- field_map[supported == TRUE]
dictionary <- as.data.table(ccao$vars_dict)
eligible_rows <- which(transactions$hie_correction_eligible)
eligible <- transactions[eligible_rows]

# Encode the baseline labels in the Assessor's code system before calling its
# update function. Unknown original labels are retained, never silently recoded.
reference_input <- data.frame(row_id = eligible$row_id)
for (i in seq_len(nrow(supported))) {
  target <- supported$target[i]
  baseline <- eligible[[supported$baseline[i]]]
  codes <- dictionary[var_name_athena == target & var_data_type == "categorical" & !is.na(var_code)]
  if (nrow(codes)) {
    stopifnot(!anyDuplicated(codes$var_code), !anyDuplicated(codes$var_value))
    encoded <- as.character(baseline)
    index <- match(encoded, codes$var_value)
    encoded[!is.na(index)] <- codes$var_code[index[!is.na(index)]]
    encoded[is.na(baseline) | trimws(as.character(baseline)) == ""] <- NA_character_
    reference_input[[target]] <- encoded
  } else {
    reference_input[[target]] <- baseline
  }
  reference_input[[supported$source[i]]] <- eligible[[supported$source[i]]]
}
# CCAO's exemption code 288 is not a replacement property class.
reference_input$qu_class <- ifelse(
  reference_input$qu_class != "288", reference_input$qu_class, reference_input$meta_class
)
reference_output <- as.data.table(ccao$chars_update(
  reference_input,
  additive_target = dplyr::all_of(supported[operation == "add", target]),
  replacement_target = dplyr::all_of(supported[operation == "replace", target])
))
# This recode immediately follows chars_update() in the pinned ingestion code.
reference_output[char_porch == "3", char_porch := "0"]

# One-to-many provenance for eligible transactions only; each source row is
# unique by (row_id, exemption_id). No transaction-level table is expanded.
source_records <- merge(
  linked_data$transaction_exemptions[row_id %in% eligible$row_id],
  exemption_data$exemptions[, c("exemption_id", supported$source), with = FALSE],
  by = "exemption_id", all.x = TRUE, sort = FALSE
)
stopifnot(!anyDuplicated(source_records[, .(row_id, exemption_id)]))
setorder(source_records, row_id, start_year, qu_upload_date, exemption_id)

field_updates <- vector("list", nrow(supported))
for (i in seq_len(nrow(supported))) {
  source_column <- supported$source[i]
  target <- supported$target[i]
  original <- eligible[[supported$baseline[i]]]
  source_value <- eligible[[source_column]]
  reference_value <- reference_output[[target]]
  proposed <- original
  status <- rep("unchanged", nrow(eligible))
  has_update <- !is.na(source_value) & as.character(source_value) != "0"

  contributing <- source_records[!is.na(get(source_column)) & as.character(get(source_column)) != "0"]
  if (supported$operation[i] == "replace" && nrow(contributing)) {
    winning_times <- contributing[!duplicated(row_id, fromLast = TRUE),
                                  .(row_id, winning_start = start_year, winning_upload = qu_upload_date)]
    contributing <- merge(contributing, winning_times, by = "row_id", all.x = TRUE, sort = FALSE)
    contributing <- contributing[start_year == winning_start & qu_upload_date == winning_upload]
  }
  contributors <- contributing[, .(
    contributing_exemption_ids = paste(sort(exemption_id), collapse = ";"),
    conflicting_replacement = supported$operation[i] == "replace" & uniqueN(get(source_column)) > 1L
  ), by = row_id]
  stopifnot(!anyDuplicated(contributors$row_id))
  contributor_index <- match(eligible$row_id, contributors$row_id)
  conflict <- !is.na(contributor_index) & contributors$conflicting_replacement[contributor_index]

  if (supported$operation[i] == "add") {
    # An increment cannot identify the total when the original total is missing.
    proposed[has_update & !is.na(original)] <- original[has_update & !is.na(original)] + source_value[has_update & !is.na(original)]
    expected_reference <- rowSums(cbind(original, source_value), na.rm = TRUE)
    stopifnot(identical(as.numeric(expected_reference), as.numeric(reference_value)))
    status[is.na(original)] <- "withheld_missing_baseline"
    decoded_reference <- reference_value
  } else {
    expected_reference <- reference_input[[target]]
    actual_source <- reference_input[[source_column]]
    nonzero <- !is.na(actual_source) & as.character(actual_source) != "0"
    expected_reference[nonzero] <- actual_source[nonzero]
    if (target == "char_porch") expected_reference[!is.na(expected_reference) & expected_reference == "3"] <- "0"
    stopifnot(identical(as.character(expected_reference), as.character(reference_value)))
    codes <- dictionary[var_name_athena == target & var_data_type == "categorical" & !is.na(var_code)]
    decoded_reference <- as.character(original)
    if (nrow(codes)) {
      index <- match(as.character(reference_value), codes$var_code)
      decoded_reference[has_update] <- codes$var_value[index[has_update]]
      known_update <- has_update & !is.na(index)
      proposed[known_update] <- codes$var_value[index[known_update]]
      status[has_update & is.na(index)] <- "withheld_unknown_replacement_code"
    } else {
      decoded_reference <- reference_value
      numeric_reference <- if (is.integer(original)) as.integer(reference_value) else as.numeric(reference_value)
      stopifnot(!any(is.na(numeric_reference) & !is.na(reference_value)))
      proposed[has_update] <- numeric_reference[has_update]
    }
    proposed[conflict] <- original[conflict]
    status[conflict] <- "withheld_tied_replacement"
    if (target == "meta_class") {
      proposed[eligible$hie_class_unresolved] <- original[eligible$hie_class_unresolved]
      status[eligible$hie_class_unresolved] <- "withheld_missing_source_class"
    }
  }
  changed <- (is.na(original) != is.na(proposed)) |
    (!is.na(original) & !is.na(proposed) & as.character(original) != as.character(proposed))
  stopifnot(!any(changed & grepl("^withheld", status)))
  status[changed] <- "applied"

  # Every audit column starts as an exact copy. Only eligible row positions can
  # receive a proposed value; sale-record property_class is never overwritten.
  set(transactions, j = supported$audit_column[i], value = copy(transactions[[supported$baseline[i]]]))
  set(transactions, i = eligible_rows, j = supported$audit_column[i], value = proposed)
  field_updates[[i]] <- data.table(
    row_id = eligible$row_id, pin = eligible$pin, sale_year = eligible$sale_year,
    baseline_column = supported$baseline[i], source_column = source_column,
    operation = supported$operation[i], original = as.character(original),
    annual_source_value = as.character(source_value), reference_code_or_number = as.character(reference_value),
    reference_value = as.character(decoded_reference), proposed = as.character(proposed),
    status = status, changed = changed,
    contributing_exemption_ids = contributors$contributing_exemption_ids[contributor_index]
  )
}
field_updates <- rbindlist(field_updates)
stopifnot(!anyDuplicated(field_updates[, .(row_id, baseline_column)]))
transactions[, hie_any_characteristic_changed := row_id %in% field_updates[changed == TRUE, row_id]]
transactions[, hie_any_withheld_update := row_id %in% field_updates[grepl("^withheld", status), row_id]]
saveRDS(list(transactions = transactions, field_updates = field_updates, field_map = field_map),
        "../output/characteristic_updates.rds")
cat(sprintf("Verified reference arithmetic for %s eligible transactions and %s supported fields.\n", nrow(eligible), nrow(supported)))
print(field_updates[, .N, by = status])
cat(sprintf("%s transactions have proposed changes; %s have at least one withheld field.\n",
            sum(transactions$hie_any_characteristic_changed), sum(transactions$hie_any_withheld_update)))
