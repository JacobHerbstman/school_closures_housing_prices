# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sale_quality_flags/code")
library(data.table)
source("../../../shared/code/report_data.R")
audit <- readRDS("../output/sale_flags.rds")
report <- capture.output({
  cat("RDS SHA-256:", digest::digest("../output/sale_flags.rds", file=TRUE, algo="sha256"), "\n")
  keys <- list(summary="group", combinations=c("group","sale_filter_same_sale_within_365","sale_filter_less_than_10k","sale_filter_deed_type"),
   annual=c("group","sale_year","reason"), prices=c("group","reason","price_band"),
   deed=c("group","sale_deed_type","sale_filter_deed_type","sale_filter_less_than_10k"), checks="check", sources="source")
  for (name in names(keys)) report_data(audit[[name]], name, keys[[name]])
})
writeLines(trimws(report, which = "right"), "../report/sale_flags.txt")
# The same mutually exclusive count table supplies the evidence note and logbook.
s <- audit$summary[match(c("Closed","Stayed open"),group)]
table <- data.table(reason=c("Records before flags", "Price at or below $10,000", "Deed type among remaining records", "Repeat among remaining records", "Pass all three flags"),
 closed=unlist(s[1,.(records,low,deed_after_low,repeat_after_low_deed,pass)]),
 control=unlist(s[2,.(records,low,deed_after_low,repeat_after_low_deed,pass)]))
md <- c("| Rule | Closed | Stayed open |", "| --- | ---: | ---: |")
tex <- c(r"(\begin{tabular}{lrr})", r"(\hline)", r"( & Closed & Stayed open \\)", r"(\hline)")
for (i in seq_len(nrow(table))) {
 row <- table[i]
 md <- c(md, sprintf("| %s | %s | %s |",row$reason,format(row$closed,big.mark=","),format(row$control,big.mark=",")))
 tex <- c(tex, paste0(paste(gsub("$", r"(\$)", row$reason, fixed=TRUE), format(row$closed,big.mark=","), format(row$control,big.mark=","), sep=" & "), r"( \\)"))
}
writeLines(c(tex,r"(\hline)",r"(\end{tabular})"),"../output/sale_flags_table.tex")
writeLines(c("# Checking the county sale-quality exclusions", "",
 "The flags are applied correctly. Every flag in the 428,582-record master matches the saved county extract by transaction ID, and every corrected record preserves those flags. All source flags contain explicit true/false values; there are no missing flags silently removing observations. No sample rule changed.", "",
 "For 2008–2018, the flags exclude 59,768 of 239,254 citywide master records. Within the school comparison, they exclude 1,795 of 5,551 records near closed schools (32.3%) and 3,666 of 12,102 near schools that stayed open (30.3%). These counts precede later property and price-per-square-foot restrictions.", "", md, "",
 "Exclusions are allocated to low price first, then deed type, then the repeat flag. The rows do not double-count overlaps. This ordering only explains the existing filter; it does not change membership.", "",
 sprintf("Of the low-price records, %s of %s near closed schools and %s of %s near controls record exactly $0 or $1. Low prices account for %.1f%% and %.1f%% of all flag exclusions, respectively.",
 format(s$low_zero_or_one[1],big.mark=","),format(s$low[1],big.mark=","),format(s$low_zero_or_one[2],big.mark=","),format(s$low[2],big.mark=","),100*s$low[1]/s$excluded[1],100*s$low[2]/s$excluded[2]), "",
 "## Definitions and limits", "",
 "**Low price:** the county SQL uses nominal price at or below $10,000, including exactly $10,000. This rule matches every master record. The field name says less_than_10k, but the implemented boundary is inclusive. Very low recorded consideration need not measure a property's market value; the audit does not establish the nature of every deed.", "",
 "**Deed type:** the county flags original instrument codes 03, 04, and 06 (quitclaim, executor, and beneficial-interest deeds), plus SQL NULL instrument types. Observed deed categories agree with the flags. A blank exported deed is ambiguous: the SQL converts an original empty string to a blank/NULL export but does not flag that original empty string. In the study-period master, 44 records have a blank deed; all have a false deed flag and only one, a $95,000 transaction, passes all three flags. We preserve the county flag.", "",
 "**Repeat:** the same parcel at the same recorded price within 365 days, calculated within the county's instrument-type grouping. This does not exclude every property resold within a year. The county computes this flag before removing some duplicate records and before substituting MyDec dates. The released export therefore cannot reproduce every repeat flag from visible sale dates alone. This audit verifies faithful transmission of the published flag, not the accuracy of unavailable source histories.", "",
 "These are the county's legacy filters, not an independent certification of arm's-length sales. Executor and quitclaim transfers can include genuine transactions; excluding those deed types remains a substantive sample choice. Jacob confirmed retaining these exclusions for the working sample on September 7, 2026. This check adds no newer outlier or PTAX flags and changes no existing restriction.", "",
 "## Reproduction", "",
 "Run make in tasks/audits/home_sale_quality_flags/code. The RDS contains all flag combinations, annual exclusions, price categories, deed counts, verification counts, and source SHA-256 hashes. Counts reconcile exactly to the descriptive packet. Descriptive and regression samples remain unchanged.", "",
 "The [county SQL](https://github.com/ccao-data/data-architecture/blob/1a64383a9a4b1791f4aa5ecc71841f6006184350/dbt/models/default/default.vw_pin_sale.sql), pinned to June 4, 2026, is acquired by Make. The [county dataset documentation](https://dev.socrata.com/foundry/datacatalog.cookcountyil.gov/wvhk-k5uv) describes the three flags as reproducing the filtering used before October 31, 2023. The SQL documents the definition; the saved extract and hashes establish the data checked.", ""), "../output/sale_flags.md")
