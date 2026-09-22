# Clean home sales

This task turns the corrected master transaction universe into the primary
2008--2018 housing-price sample with complete required property characteristics,
plus a 2008--2023 file built by the same within-year rules. It applies Cook County's [three published sale-quality
flags](https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv), requires a
non-land transaction above $10,000, and removes foreclosure auctions and
transfers to lenders (below). The county flags cover nominal prices at or below
$10,000 (including exactly $10,000), selected deed types, and the same parcel
at the same recorded price within 365 days. The repeat flag does not exclude
every property resold within a year. The deed flag covers quitclaim, executor,
and beneficial-interest instruments and source SQL NULL types; a blank exported
type is not sufficient to reconstruct that rule. These reproduce the county's
legacy filters and do not independently establish an arm's-length sale. The
source-to-output check and exclusion counts are in
`tasks/audits/home_sale_quality_flags/`.

The task then removes foreclosure auctions (judicial-sale companies, sheriffs,
selling officers as seller) and transfers to a lender, servicer, Fannie Mae,
Freddie Mac, HUD, the VA or the Cook County Land Bank. These prices are credit
bids or paperwork, not market prices. Resales *by* those institutions (REO
sales, including subprime consumer-finance lenders such as Household Finance or
Residential Funding and national banks acting as securitization trustees) are
market sales of distressed homes. Foreclosure incidence may respond to
closures, so they stay in the sample, flagged `reo_sale` (about a third of
2008--2012 sales and a sixth afterwards). Banks acting as Chicago land trustees
convey ordinary sales and are neither. Party names come from the raw
parcel-sales extract (joined by `row_id`) and are available in every year, so
the rules apply alike before and after 2013. MyDec deed types begin in 2013
and are used only when the seller name is missing (almost entirely 2014--2016,
and 46 percent of 2015 sales): court and officer deeds count as auctions,
deeds in lieu of foreclosure as transfers to a lender, and special warranty
deeds as REO. Among post-2012 sales with known sellers, the names identify 98
percent of judicial-sale deeds and 80 percent of special warranty deeds as
foreclosure-related, but under 1 percent of warranty deeds and 3 percent of
trustee deeds. The literal patterns are in the script.

`same_party_names` flags sales whose normalized buyer and seller names are
identical, excluding land trustees, which appear on both sides of ordinary
sales. Such transfers may be between related parties at non-market prices.
Surname matching was rejected because name order and common surnames make it
unreliable. The output retains `sale_seller_name` and `sale_buyer_name`.

Quick resales are flagged, not dropped. `days_since_previous_sale` and
`days_until_next_sale` measure the gap to the same parcel's adjacent recorded
sale, and `resale_within_365` marks a sale within 365 days of the previous one.
Gaps use every 2006--2025 market sale (county flags, non-land, above $10,000),
the same definition as the first sample restriction, including
foreclosure auctions removed from the price sample, so a resale after a
foreclosure purchase is flagged. The assessor's
characteristics do not record renovation between the two sales. Pre-2013 dates
are known only to the month, so those gaps are measured to the month. Multi-parcel
purchases are not in the master and cannot start a gap.

The sample requires one improvement card lying wholly on the sold parcel
(`res_tieback_proration_rate` of 1; a lower rate splits one building across
parcels, so its characteristics describe more than was sold), excludes class
212 mixed-use, and
requires complete year built, building and land square footage, bedrooms,
rooms, full bathrooms, residential type, construction quality, and condition.
Class 211 contains two-to-six-unit apartment buildings. A blank unit count is
kept as unknown (`apartment_count` missing) rather than excluded: blanks are
8 percent of class-211 sales, concentrated in Lake township, falling over time,
and cheaper (median $135,000 vs $256,000), so requiring a count would remove
buildings unevenly. Regressions that control for unit count need an unknown
category. All class restrictions use `analysis_class`, not the
unchanged sale-record class. The upstream correction task resolves property
type consistently with observed use and apartment count; unresolved types
remain missing and do not enter this sample.

The output remains one row per transaction and is keyed by `row_id`.
Alongside required-field and property-type consistency checks, the numerical
integrity exclusions remain fewer total rooms than bedrooms and recorded prices
above $5,000 per building square
foot. Low-price crash-era transactions remain. The output is
not geocoded or assigned to a school.

No percentile trim is applied. `price_outside_p01_p99` flags sales outside
the within-year citywide 1st--99th percentiles of nominal price, computed on
the final sample (including REO resales) with R's `quantile(type = 7)`, for
the conventional trimming check. A price cutoff flags houses and
two-to-six-unit buildings in proportion; a per-square-foot cutoff would mostly
flag large, cheap apartment buildings. An earlier within-year 99.9th-percentile
price-per-square-foot trim was removed on September 22, 2026 so that one tail
rule remains. The broad master transaction universe is retained for activity
work.

Flags for robustness checks are `reo_sale`, `resale_within_365` (with the gap
columns), `same_party_names`, and `price_outside_p01_p99`. None removes a sale.

At the end of sample construction, nominal sale price is deflated with the
monthly Chicago-Naperville-Elgin CPI-U all-items index. The output retains
`sale_price_nominal` and adds the CPI, the deflator to average 2022 dollars,
`sale_price_real_2022`, and `price_per_building_sqft_real_2022`. No CPI values
are interpolated.

Run `make` from `code/`. Before/after membership, counts, and price trends are
documented in `tasks/audits/home_sales_finalization/`.

The normal build also writes a standard data report in `report/`, including
the saved CSV checksum, transaction key checks, missingness, and distributions.
