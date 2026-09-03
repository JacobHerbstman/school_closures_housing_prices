suppressPackageStartupMessages(library(data.table))

transactions <- fread(
  "../input/home_sales_with_characteristics_2006_2025.csv",
  colClasses = list(character = c("row_id", "pin", "sale_document_num"))
)
exemption_data <- readRDS("../output/exemption_years.rds")
annual <- exemption_data$annual
stopifnot(
  !anyDuplicated(transactions$row_id),
  !anyDuplicated(annual[, .(pin, sale_year)]),
  all(transactions[single_improvement_card == TRUE, improvement_card_count] == 1L),
  all(transactions[single_improvement_card == TRUE, res_pin_is_multicard] == FALSE),
  all(transactions[single_improvement_card == TRUE, res_pin_num_cards] == 1L)
)
transactions[, source_order := .I]

# Many transactions to one annual correction. This is not a sample filter.
linked <- merge(transactions, annual, by = c("pin", "sale_year"), all.x = TRUE, sort = FALSE)
setorder(linked, source_order)
stopifnot(nrow(linked) == nrow(transactions), !anyDuplicated(linked$row_id))
for (column in names(transactions)) {
  stopifnot(identical(linked[[column]], transactions[[column]]))
}
linked[, `:=`(
  hie_source_active = !is.na(exemption_record_count),
  hie_correction_eligible = !is.na(exemption_record_count) & single_improvement_card & sale_year < 2021L,
  hie_start_year_timing_uncertain = !is.na(exemption_starts_this_year) & exemption_starts_this_year,
  hie_class_unresolved = !is.na(class_source_missing) & class_source_missing & is.na(qu_class)
)]
linked[, hie_status := fcase(
  !hie_source_active, "no_active_legacy_exemption",
  sale_year >= 2021L, "already_in_post2020_source",
  !single_improvement_card, "not_single_card",
  default = "eligible_pre2021_single_card"
)]

# Intentional one-to-many provenance: a transaction may have several active
# exemptions. The key is (row_id, exemption_id), not row_id alone.
membership <- exemption_data$membership
stopifnot(!anyDuplicated(membership[, .(pin, sale_year, exemption_id)]))
transaction_exemptions <- merge(
  linked[hie_source_active == TRUE, .(row_id, pin, sale_year)], membership,
  by = c("pin", "sale_year"), all = FALSE, allow.cartesian = TRUE, sort = FALSE
)
stopifnot(!anyDuplicated(transaction_exemptions[, .(row_id, exemption_id)]))
transaction_exemptions <- merge(
  transaction_exemptions,
  exemption_data$exemptions[, .(exemption_id, start_year, last_active_year, qu_upload_date)],
  by = "exemption_id", all.x = TRUE, sort = FALSE
)
stopifnot(
  !anyNA(transaction_exemptions$start_year),
  all(transaction_exemptions$start_year <= transaction_exemptions$sale_year),
  all(transaction_exemptions$last_active_year >= transaction_exemptions$sale_year),
  nrow(transaction_exemptions) == sum(linked$exemption_record_count, na.rm = TRUE)
)
setorder(transaction_exemptions, row_id, exemption_id)
linked[, source_order := NULL]
saveRDS(list(transactions = linked, transaction_exemptions = transaction_exemptions),
        "../output/linked_transactions.rds")
cat(sprintf("All %s transaction rows and original fields preserved.\n", nrow(linked)))
print(linked[, .N, by = hie_status])
cat(sprintf("Verified %s transaction-to-exemption links; none before start or after expiration.\n", nrow(transaction_exemptions)))
