suppressPackageStartupMessages(library(data.table))
audit <- readRDS("../output/sample_reconciliation.rds")

# Used for each substantive table; detailed row-level evidence is in the RDS.
markdown_table <- function(table) {
  table <- as.data.frame(table)
  for (name in intersect(c("sale_year", "township_code", "neighborhood_code"), names(table))) {
    table[[name]] <- as.character(table[[name]])
  }
  table[] <- lapply(table, function(column) {
    if (is.numeric(column)) format(round(column, 6), trim = TRUE, scientific = FALSE, big.mark = ",")
    else as.character(column)
  })
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(table)), collapse = " | "), " |"),
    apply(table, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |")), "")
}
conversion_review <- audit$class_review[coherent_conversion == TRUE]
conversion_matched <- conversion_review[followup_found == TRUE]
lines <- c(
  "# Housing-side sample reconciliation", "",
  "## What is fixed, and what is not", "",
  "All exemption corrections now precede analytical sample selection. Production preserves every master transaction, the original sale class, the original improvement fields, and source exemption IDs. Uncertain replacement fields stay missing; a missing correction never silently restores an older value.", "",
  "The analysis class comes from the corrected same-year improvement record. Single-family classes paired with observed multiple apartments or multifamily use, and class 211 paired with no apartments or single-family use, receive a missing analysis class. These conflicts stay in the master but not the complete-hedonic price sample. Missing use alone is not an extra complete-case restriction. Missing apartment count still excludes class 211. Class 212 stays outside the price sample. No class-size-band, percentile, or new PPSF trimming was added.", "",
  "This is an internally consistent housing-side sample, not proof that every physical characteristic or conversion date is historically correct. Annual exemption timing cannot establish whether work preceded a sale within its start year. Later assessor observations are diagnostics, never historical replacement inputs.", "",
  "## Selection, including the stale-class diagnostic", "",
  markdown_table(audit$variants),
  sprintf("%s sales are common to both the previous and final samples. %s are removed and %s added. These are pre-geocoding counts.",
          format(audit$unchanged_transactions, big.mark = ","),
          format(audit$changes[membership == "removed", .N], big.mark = ","),
          format(audit$changes[membership == "added", .N], big.mark = ",")), "",
  markdown_table(audit$funnel),
  "Each changed row is assigned its first failing restriction; overlapping reasons are not double-counted.", "",
  markdown_table(audit$change_reasons),
  sprintf("The final sample includes %s originally class-211 sales now coherently classified as single-family. Of these, %s were in the previous sample, and %s are newly admitted. Keeping the stale sale class would incorrectly impose the apartment-count requirement on these corrected records.",
          nrow(audit$conversions), sum(audit$conversions$old_included), sum(!audit$conversions$old_included)), "",
  sprintf("%s master transactions have an unresolved HIE field. The price sample retains %s of these transactions because its unresolved field is not required by the core-hedonic definition. No imputation was applied.",
          audit$unresolved_master, audit$unresolved_retained), "",
  "## Property-class review", "",
  "The review includes every HIE-eligible transaction with a broad property-group change or an internal class/use/apartment conflict across 2006–2025. Several sales can refer to the same PIN-year, so sales are not independent validation cases. Follow-up is the first year after all exemptions active at the sale have expired. Only observed single-card follow-ups enter agreement counts.", "",
  markdown_table(audit$class_validation),
  "The final row pools other changes and missing corrected classes; missing classes do not constitute proposed values to validate. The detailed RDS separates all source and corrected groups.", "",
  sprintf("Among %s internally coherent 211-to-single-family changes, %s have a usable later record. Later broad property group agrees for %s; apartment count agrees for %s; use agrees for %s. These checks corroborate many, not all, conversions. Disagreement may reflect source errors, later changes, or incomplete rollover; it does not identify which sale-year field to replace.",
          nrow(conversion_review), nrow(conversion_matched),
          sum(conversion_matched$group_agrees), sum(conversion_matched$apartments_agree), sum(conversion_matched$use_agrees)), "",
  sprintf("Within the selected 2008–2018 price sample, %s coherent conversions have a usable later record; later property group agrees for %s, apartment count for %s, and use for %s. Later disagreement remains visible in the audit and is not used as a retrospective sample restriction.",
          conversion_matched[selected_price_sample == TRUE, .N],
          conversion_matched[selected_price_sample == TRUE, sum(group_agrees)],
          conversion_matched[selected_price_sample == TRUE, sum(apartments_agree)],
          conversion_matched[selected_price_sample == TRUE, sum(use_agrees)]), "",
  "Among all matched coherent conversions, agreement by follow-up system period:", "",
  markdown_table(conversion_matched[, .(matched_sales = .N, group_agrees = sum(group_agrees)),
                                    by = .(followup_period = fifelse(check_year >= 2021L, "2021 or later", "Before 2021"))]),
  "The conflict rule is applied to existing records as well as HIE-updated ones:", "",
  markdown_table(audit$class_conflicts),
  "## Price, size, composition, and geography checks", "",
  markdown_table(audit$distribution),
  markdown_table(audit$trend_checks),
  markdown_table(dcast(audit$annual, sale_year ~ version, value.var = "sales")),
  "Largest proportional neighborhood sample changes (all assessor neighborhoods, without a minimum-cell exclusion):", "",
  markdown_table(head(audit$neighborhoods[, .(township_code, neighborhood_code, sales_old, sales_new, net_sales, share_change_pct)], 10)),
  "![Before-and-after comparison](sample_comparison.png)", "",
  "## Coordinate checks and housing-side freeze", "",
  markdown_table(audit$coordinate_summary),
  sprintf("All coordinate joins are exact PIN-year matches. The maximum discrepancy between county EPSG:3435 coordinates and longitude/latitude transformed from EPSG:4326 is %.6f US survey feet. All tested points have valid geometry. Blank coordinates stay flagged in the broad master and are excluded only from the final geocoded price sample.", audit$max_projection_error_ft), "",
  "The broad geocoded 2006–2025 master is independent of all analytical sample restrictions. It is the intended input for future distances to every supplied school. No schools, buffers, nearest-school assignment, or treatment rules have been created.", "",
  markdown_table(audit$date_precision),
  "Use monthly or coarser treatment timing. Monthly recording dates are not exact execution dates.", "",
  "SHA-256 fingerprints identify the reviewed outputs; rerunning changed upstream data requires a fresh reconciliation. This is a documented snapshot, not a promise that mutable public APIs will return the same content forever.", "",
  markdown_table(audit$hashes),
  "## Reproduction and detailed evidence", "",
  "Run `make` from this task's `code/` directory. `sample_reconciliation.rds` contains changed sale IDs and reasons, class transitions, all class follow-ups, monthly and annual summaries, neighborhood comparisons, missing coordinates, and fingerprints. `class_followups.rds` preserves the exact API queries, responses, and retrieval time. No audit artifact enters the production graph.", "",
  "Every supported corrected field agrees with the earlier careful audit on every master row. Every original field is preserved, all non-corrected baseline fields are unchanged, all correction links fall within their active-year intervals, selected IDs independently reproduce the cleaner, and geocoding preserves every retained sale field.", "",
  "## Primary sources", "",
  "- [Assessor HIE documentation](https://github.com/ccao-data/wiki/blob/master/Residential/Home-Improvement-Exemptions.md): frozen legacy characteristics, additive/replacement corrections, rollover, and historical sales use.",
  "- [Pinned Assessor characteristic functions](https://github.com/ccao-data/ccao/blob/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/R/chars_funs.R) and [field mapping](https://github.com/ccao-data/ccao/blob/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/data-raw/chars_cols.R).",
  "- [Assessor property-class dictionary](https://github.com/ccao-data/data-architecture/blob/33fc006de85317147dbed471e88960048157f1db/dbt/seeds/ccao/ccao.class_dict.csv): single-family, class 211 apartments, and class 212 mixed-use definitions.",
  "- [Legacy improvement metadata](https://datacatalog.cookcountyil.gov/api/views/bcnq-qi2z): residence-code harmonization.",
  "- [Historical improvement metadata](https://datacatalog.cookcountyil.gov/api/views/x54s-btds): follow-up records.",
  "- [Parcel-sales metadata](https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv) and [historical parcel metadata](https://datacatalog.cookcountyil.gov/api/views/nj4t-kc8j).", ""
)
writeLines(lines, "../output/finalization.md")
