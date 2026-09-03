# Home-sales sample definition audit

This audit preserves the pre-HIE 2008--2018 non-condominium price-sample review.
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
themselves, evidence of a recording error. The production exclusion flag marks
only sales above $5,000 per square foot and records with fewer total rooms than
bedrooms. The first rule catches seven implausibly large recorded prices; the
second catches an internally impossible characteristic record. No percentile
trimming or winsorization is used.

Run `make` from this task's `code/` directory.
