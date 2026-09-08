# Housing-side finalization audit

Run `make` from `code/`. The final products are `output/finalization.md` and
`output/sample_comparison.png`. This audit is not an input to production.
It requires the production R packages plus `sf` and the packages listed in the
[home-improvement exemption audit](../home_improvement_exemptions/).

The audit checks every corrected field against the rule-based
[home-improvement exemption audit](../home_improvement_exemptions/),
preservation of originals and transaction identity, correction timing, sample
membership, and exact historical coordinates. It independently reconstructs
the previous selection rules and compares them with the current cleaner,
including its within-year 99.9th-percentile price-per-square-foot trim. The
report lists annual cutoffs and exclusions; the detailed RDS assigns the trim
as an exclusion reason to each affected transaction.
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
The report records the source-file versions used for these housing checks.
The downstream school-exposure and estimation tasks define the treated and
control transaction groups.
