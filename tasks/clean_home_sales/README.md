# Clean home sales

This task turns the corrected master transaction universe into the primary
2008--2018 housing-price sample with complete required property characteristics. It applies Cook County's [three published sale-quality
flags](https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv), requires a
non-land transaction above $10,000, and does not impose an additional deed-type
or buyer/seller-name rule. The county flags cover nominal prices at or below
$10,000 (including exactly $10,000), selected deed types, and the same parcel
at the same recorded price within 365 days. The repeat flag does not exclude
every property resold within a year. The deed flag covers quitclaim, executor,
and beneficial-interest instruments and source SQL NULL types; a blank exported
type is not sufficient to reconstruct that rule. These reproduce the county's
legacy filters and do not independently establish an arm's-length sale. The
source-to-output check and exclusion counts are in
`tasks/audits/home_sale_quality_flags/`.

The sample requires one improvement card, excludes class 212 mixed-use, and
requires complete year built, building and land square footage, bedrooms,
rooms, full bathrooms, residential type, construction quality, and condition.
Class 211 contains two-to-six-unit apartment buildings and must have an
observed apartment count. All class restrictions use `analysis_class`, not the
unchanged sale-record class. The upstream correction task resolves property
type consistently with observed use and apartment count; unresolved types
remain missing and do not enter this sample.

The output remains one row per transaction and is keyed by `row_id`.
Alongside required-field and property-type consistency checks, the numerical
integrity exclusions remain fewer total rooms than bedrooms and recorded prices
above $5,000 per building square
foot. Low-price crash-era transactions remain. The output is
not geocoded or assigned to a school.

After those screens, the task removes sales strictly above the 99.9th percentile
of nominal price per building square foot within each sale year. The cutoff is
computed once on that year's otherwise eligible citywide sample, combining
property types and school-exposure groups, using R's `quantile(type = 7)`.
Ties at the cutoff remain. There is no lower-tail trim or winsorization.
The build reports each year's cutoff and number removed. This is a price-sample
restriction; the broad master transaction universe is retained for activity work.

At the end of sample construction, nominal sale price is deflated with the
monthly Chicago-Naperville-Elgin CPI-U all-items index. The output retains
`sale_price_nominal` and adds the CPI, the deflator to average 2022 dollars,
`sale_price_real_2022`, and `price_per_building_sqft_real_2022`. No CPI values
are interpolated.

Run `make` from `code/`. Before/after membership, counts, and price trends are
documented in `tasks/audits/home_sales_finalization/`.

The normal build also writes a standard data report in `report/`, including
the saved CSV checksum, transaction key checks, missingness, and distributions.
