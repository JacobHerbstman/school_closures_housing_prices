# Home-sales sample definition audit

This audit preserves the 2008--2018 non-condominium price-sample review from before
the home-improvement exemption corrections.
It is historical diagnostic evidence, not the current production sample.
For corrected characteristics and consistent property types, see
`tasks/audits/home_sales_finalization/`.

This audit reconstructs the earlier sample
from the characterized transaction universe. It records attrition from the
market-sale restrictions, the one-card requirement, exclusion of class 212,
and complete core hedonics. Class 211 contains two-to-six-unit apartment
buildings and must have an observed apartment count.

The price review is deliberately conservative. Sales below $5 per square foot
remain in the sample because they cluster in the housing crash and are not, by
themselves, evidence of a recording error. The historical exclusion flag marks
only sales above $5,000 per square foot and records with fewer total rooms than
bedrooms. The first rule catches seven implausibly large recorded prices; the
second catches an internally impossible characteristic record. This historical audit uses no percentile
trim. The current cleaner also removes the top 0.1 percent of price per square
foot within each year; see [clean_home_sales](../../clean_home_sales/).

Run `make` from this task's `code/` directory.
