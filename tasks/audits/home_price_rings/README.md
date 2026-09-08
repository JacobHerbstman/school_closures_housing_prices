# Distance-ring comparisons around the fixed 30/49 school split

The [quarter-mile analysis](../home_prices_twfe/) is the working comparison.
This audit examines sensitivity to the distance between homes and schools.

This audit compares annual raw prices, DiDs, and event studies in three
annuli (0–0.125, 0.125–0.25, 0.25–0.5 miles) and two cumulative buffers
(0–0.25 and 0–0.5 miles). The 30 treated/49 control school flags and citywide
price-sample cleaning are unchanged. This is exploratory and feeds no
production dataset.

Run `make` in `code/`. Make manages fixed input links and all outputs.
Distances are the existing EPSG:3435 distances in feet (5,280 feet per mile).
The nearest focal school site defines the home assignment. At the outer
radius of each specification, exclude homes near any second focal site,
including same-status sites, and homes near a school designated to receive displaced students (a welcoming
school) or another candidate school outside the 30/49 comparison. A home in an annulus must have its nearest focal site in that annulus;
a home closer to a different site cannot enter a distant site's ring.
Outer edges are included; positive inner edges are excluded. This stricter
overlap rule differs from the preceding quarter-mile audit, which retained
same-status overlaps. The exclusion funnel makes that difference explicit.

`ring_assignments.parquet` has one row per (ring, transaction). A transaction
can enter several cumulative or annular specifications, but enters each
specification once. `report/ring_assignments.txt` documents the saved data.
The supplied school treatment flags remain site attributes; all analysis is
about proximity to buildings, not attendance-zone residence.

`sample_summary.csv` records the exclusion funnel, counts by treatment group,
pre/post support, and pre-2013 price/housing summaries. `site_year_support.csv`
includes zero-sale years for sites appearing in each ring. `raw_trends.csv`
contains annual unadjusted means, under equal transaction and equal observed
site-year weights. The latter gives each sale weight 1/site-year sales.
Missing site-years have no imputed prices.

Annual DiDs compare 2008–2012 with 2014–2018, omitting 2013. Event studies
include 2013 and normalize 2012 to zero. Both price levels (2022 dollars)
and logs are estimated under both weighting schemes, without and with the
housing controls listed in the [quarter-mile analysis](../home_prices_twfe/). No amenities or Census
demographics are added while varying distance. Intervals cluster by site;
pre-period joint tests use cluster count minus one denominator degrees of
freedom. Prices remain conditional on sale.

In the main specification, school-site fixed effects allow a separate
persistent intercept for each school's nearby housing market. Each ring is
estimated separately, so site intercepts can differ across ring samples.
They do not absorb school-specific time paths. A separate hedonic diagnostic
replaces site intercepts with a single treated/control group difference,
while retaining year effects. This shows sensitivity to site composition;
it does not establish that dropping site fixed effects improves identification.

The three annular bands appear in the raw-price and event-study figures.
The five-band pooled DiD figure also includes the cumulative buffers.
Figures show raw prices, event studies without and with hedonics, the
site-versus-group fixed-effect diagnostic, and pooled DiDs by distance.
Coefficient tables and sample counts are retained for inspection. Because
overlap exclusions expand with the outer radius, these ring samples need not
contain the same sites or neighborhoods. Cumulative estimates combine inner
and outer areas; annular estimates are local comparisons, not independent
experiments or estimates of distance decay holding neighborhoods fixed.

## Fixed half-mile exclusions and common sites

The `common_*` outputs hold the exclusion radius at 0.5 mile in every band.
They start from the existing strictly isolated half-mile assignments, then
split those homes into the same three annuli. An eligible site-year must
have at least one sale in **each** annulus. Retain sites with at least one
such common year before 2013 and one after 2013; retain their eligible years,
including 2013 when available. Thus both the overall site roster and the
contributing roster within each year are identical across bands. The roster
can still change from year to year. No prices are imputed.

This stronger coverage rule prevents empty inner-ring cells from changing
the schools compared across bands. It selects on observed transaction
activity, including post-closure activity, and therefore changes the target
population. This is a sample-composition diagnostic, not a proposed main
sample or a solution to selection into sale.

`common_support.csv` records the full site × band × year grid for every site
with any eligible half-mile sale, with empty cells, common-year eligibility,
and roster inclusion. `common_sample_summary.csv` shows successive counts
under the half-mile exclusions, common roster, and common-year restrictions.
`common_ring_assignments.parquet` records the retained transactions, including
cumulative buffers formed from exactly the same site-years. Its standard
report also summarizes the saved support grid. Estimates, controls, weights,
and clustering otherwise match the previous analysis. The shared estimation
and plotting scripts accept `varying` or `common` as the actual design choice;
Make declares both sets of concrete products. Prior results remain separate.

`report/saved_tables.txt` describes the saved summary tables, verifies their
keys, and records their checksums. It is rebuilt by the normal Make target.
