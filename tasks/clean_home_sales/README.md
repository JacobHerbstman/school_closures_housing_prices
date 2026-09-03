# Clean home sales

This task turns the corrected master transaction universe into the primary
2008--2018 complete-hedonic housing-price sample. It is not a measure of all
housing-market transactions. It applies Cook County's [three published sale-quality
flags](https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv), requires a
non-land transaction above $10,000, and does not impose an additional deed-type
or buyer/seller-name rule.

The sample requires one improvement card, excludes class 212 mixed-use, and
requires complete year built, building and land square footage, bedrooms,
rooms, full bathrooms, residential type, construction quality, and condition.
Class 211 contains two-to-six-unit apartment buildings and must have an
observed apartment count. All class restrictions use `analysis_class`, not the
unchanged sale-record class. The upstream correction task resolves property
type consistently with observed use and apartment count; unresolved types
remain missing and do not enter this sample.

The output remains one row per transaction and is keyed by `row_id`. It is not
winsorized or percentile-trimmed. Alongside required-field and property-type
consistency checks, the existing numerical integrity exclusions remain fewer
total rooms than bedrooms and recorded prices above $5,000 per building square
foot. Low-price crash-era transactions remain. The output is
not deflated, geocoded, or assigned to a school.

Run `make` from `code/`. Before/after membership, counts, and price trends are
documented in `tasks/audits/home_sales_finalization/`.
