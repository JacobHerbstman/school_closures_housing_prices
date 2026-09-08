# County sale-quality flags

Check the three Cook County sale flags against the saved source extract and explain their contribution to sample attrition in 2008–2018. The audit compares flags by transaction ID through the master and corrected files, checks the price and observable deed rules, and reconciles the first two rows of the descriptive packet's sample counts. Counts include overlaps and a mutually exclusive allocation: low price first, then deed type, then repeat sale.

Run `make` in `code/`. `output/sale_flags.md` explains the findings; `output/sale_flags.rds` contains the supporting tables, described in `report/sale_flags.txt`. `output/sale_flags_table.tex` supplies the logbook table.

The Makefile acquires the county's SQL at commit `1a64383a9a4b1791f4aa5ecc71841f6006184350` (June 4, 2026). This is documentation of the county's current implementation, not a claim that its historical source database can be reconstructed. The existing parcel-sales extract is reused without refresh. Source hashes are saved with the audit.

The repeat flag uses the same parcel and price within 365 days, calculated before the county removes some duplicate records and substitutes MyDec dates. Those hidden records and original dates prevent exact independent reconstruction from the published export. Blank deed fields also do not reveal whether the original value was an empty string or SQL NULL; the county treats these differently. The audit preserves the published flags and records these limits.

The working sample retains all three legacy filters, including the deed-type
exclusions, as confirmed on September 7, 2026. This matches the deed exclusions
described in the [Assessor's residential model documentation](https://github.com/ccao-data/model-res-avm/blob/master/README.md#types-of-sales-excluded);
we do not reproduce all of that model's additional exclusions.
