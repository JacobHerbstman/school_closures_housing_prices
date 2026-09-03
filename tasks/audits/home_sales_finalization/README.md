# Housing-side finalization audit

Run `make` from `code/`. The final products are `output/finalization.md` and
`output/sample_comparison.png`. This audit is not an input to production.
It requires the production R packages plus `sf`, and the original HIE audit's
documented R dependencies for reference reconstruction.

The audit checks every corrected field against the earlier careful HIE trial,
preservation of originals and transaction identity, correction timing, sample
membership, and exact historical coordinates. It independently reconstructs
the previous selection rules and compares them with the current cleaner.
Annual/monthly trends and assessor-neighborhood comparisons distinguish
physical corrections from sample composition changes.

`download_class_followups.R` selects all HIE-eligible transactions with a broad
property-group change or a class/use/apartment contradiction. It retrieves the
first post-expiry record, preserves the queries and retrieval time, and
reports agreement only for observed single-card records. These later values
never enter historical corrections. Agreement is corroboration, not proof;
disagreement is not automatically an error at sale.

`sample_reconciliation.rds` contains all changed sale IDs and exclusion
reasons, class transitions, follow-up comparisons, monthly/annual summaries,
neighborhood changes, missing-coordinate records, and reviewed file hashes.
The report identifies the frozen housing-side snapshot. The coauthor's school
file and exposure definitions are still needed for a treated/control sample.
