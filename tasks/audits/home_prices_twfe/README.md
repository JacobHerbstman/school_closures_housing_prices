# Housing-price DiD and event studies

This task compares home prices near 30 closed and 49 still-open schools
selected from the February 2013 closure-consideration list. It estimates
difference-in-differences (DiD) models and annual and semiannual event studies.
Start with `event_studies.png` and `event_studies_semiannual.png`, which
give every transaction equal weight. Equal-site results remain a sensitivity
comparison in `event_studies_weights_annual.png`.
Alternative distance bands are documented in
[`home_price_rings`](../home_price_rings/).

Run `make` from `code/`. This exploratory task stays in audits. It requires
`data.table`, `DBI`, `duckdb`, and `fixest`; the model summary records the
installed `fixest` version.

The observation is a home transaction from the final 2008–2018 price sample,
including its within-year 99.9th-percentile nominal price-per-square-foot trim.
Include sales within one-quarter mile of a treated or control school site.
Exclude homes within that radius of both groups, of a school designated to
receive displaced students (a welcoming school), or of another school on the
February candidate list outside the 30/49 comparison. The
`housing_treat_30`/`housing_control_49` exposure definitions determine group
membership. Never-listed schools are not controls. A home near multiple sites
of the same status enters once and uses the nearest corresponding site for
its fixed effect and standard-error cluster.

The task estimates log real prices and prices in 2022 dollars, each with
school-site and sale-year fixed effects, both without controls and with
housing characteristics. The transaction-weighted models give each sale equal weight. The site-weighted
models give each school area equal total weight within an observed period. Standard errors
cluster by school site, using `fixest`'s default finite-sample adjustments.
These are repeated-cross-section estimates of prices conditional on sale;
changes in the mix of homes and locations selling can affect the estimates.

The hedonic models add log building square feet, log lot square feet, and age
at sale, each with its square; linear bedroom, room, full-bathroom, and
apartment counts; and categorical indicators for property class, residence
type, construction quality, and repair condition. These controls enter jointly with the treatment effects.
The housing-control models use annual or half-year time effects; amenity
controls enter separately as described below. The sales cleaner requires
complete characteristics, so adding controls retains
the same transactions. An inapplicable apartment count is coded zero outside
class 211, with property class included separately. Split-level residence type
is redundant with class 234 in this sample; the estimator drops that redundant
indicator and the model summary records it.

Characteristics are the corrected Assessor records attached to the sale year,
not a frozen pre-closure snapshot. Condition and physical improvements could
respond to closure. The controlled specification compares prices holding
observed housing quality fixed; it should not automatically replace the
uncontrolled specification as an estimate of the total effect.

The pooled DiD compares 2008–2012 with 2014–2018, excluding the 2013 transition
year. The annual event study includes all years and normalizes 2012 to zero.
Its 2013 coefficient combines pre-announcement and post-announcement/closure
sales. It therefore measures a mixture of sales made before and after the
closure decisions, rather than a full year after closure. The joint pre-period test covers 2008–2011 relative to 2012; failure
to reject does not establish parallel trends. The joint test uses the clustered
covariance matrix and an F reference distribution with four numerator degrees
of freedom and the number of school-site clusters minus one in the denominator.
CIs are pointwise, not simultaneous.

Semiannual event studies use January-June and July-December periods, replace
sale-year fixed effects with calendar-half-year fixed effects, and normalize
2012 H2 to zero. Both halves of 2013 are displayed; H1 mixes pre-announcement
and post-announcement/vote sales, while H2 follows the end-of-year closure.
The sample, property controls, clustering, and annual price-per-square-foot
trim are unchanged. The joint pre-period test covers the nine half-years from
2008 H1 through 2012 H1, using an F(9,76) reference distribution in this run.
`sale_halfyear` and `reference_halfyear` encode H1 as the year and H2 as year
plus 0.5. The annual pooled DiD remains unchanged.

Outputs:

- `coefficients.csv`: treatment coefficients for all thirty-six models, clustered standard errors,
  p-values, and 95% confidence intervals. Log coefficients are in log points.
- `model_summary.csv`: sample sizes, cluster counts, reference periods, and
  joint pre-period tests.
- `site_year_support.csv`: observed transaction counts and price summaries by
  school site and year. These counts describe the selected price sample, not
  market activity or turnover rates; absent rows indicate no selected sales.
- `event_studies.png`: annual event studies without and with hedonics, using
  the same vertical scale across specifications of each outcome.
- `event_studies_semiannual.png`: the corresponding four semiannual panels.

The September 4, 2026 run uses 10,921 transactions for the event studies and
9,912 for the DiD, across 29 treated and 48 control sites. Adding hedonics
changes the pooled log estimate from 0.0744 to 0.0552 and the dollar estimate
from $62,880 to $56,983. The corresponding joint pre-period p-values change
from 0.240 to 0.700 for logs and 0.028 to 0.233 for dollars. Independent
dummy-variable OLS reproduces the four controlled models' treatment
coefficients within 0.000001; the four uncontrolled models reproduce the
previous run. The dated interpretation is in `logbook/` at the repository root.

School-site clustering does not address all possible spatial dependence across
nearby sites. Spillovers beyond the exclusion rings, endogenous closure
selection, and transaction composition remain identification concerns. The
broad master is preserved for a separate market-activity analysis with a
justified denominator.

In the semiannual models with housing controls,
pre-period p-values are 0.967 for logs and 0.572 for dollars. Log estimates
continue to fluctuate around zero after closure; positive dollar estimates
persist, particularly in 2016-2018. Smaller periods produce less precise
estimates and do not by themselves explain the difference between outcomes.

## Amenities interacted with half-year

The amenity extension adds each home's distance in miles to the Lake Michigan
shoreline, the nearest August 2012 park polygon, and the nearest archived
2012 CTA station. Each distance has its own slope in every calendar half-year,
common across treatment groups. All half-year slopes are included, including
the reference half-year: 66 slopes in the event study and 60 in the pooled
DiD that omits 2013. They are linear in miles, allowing the relationship between amenity proximity
and prices to differ across half-years.
The original housing characteristics and school-site fixed effects remain.

The inputs come from `home_amenity_distances`, whose data report records
source fingerprints, geometry validation, and missingness. The distance data
retain all 167,468 clean sales, with one missing centroid; all 10,921 preferred
ring transactions have complete distances. Thus the model comparisons have
no sample attrition. `download_baseline_amenities` downloads the public
geographies through Make; GIS files and downloaded metadata are ignored by
Git. See that task's README for the archived CTA layer's provenance and the
historical-vintage limitations. Metra, bus access, and the 2013 Red Line South
reconstruction are not separately modeled.

`event_studies_amenities.png` compares semiannual hedonic event studies without
and with these interactions. The four `did_semiannual_*` models provide a
pooled comparison with half-year time effects in both specifications. The
old annual DiD should not be used as the exact no-amenity comparator, because
it uses year time effects. `model_summary.csv` identifies amenity controls.

In the September 4 run, adding amenity interactions changes the semiannual
pooled log estimate from 0.0611 to 0.0457 and the dollar estimate from $57,768
to $58,521. The amenity-adjusted 95% intervals are [-0.1208, 0.2121] in logs
and [$2,781, $114,262] in 2022 dollars. Event-study pre-period p-values are
0.906 for logs and 0.334 for dollars. This specification does not establish that all neighborhood recovery paths
are adequately controlled; it allows a particular linear relationship between
baseline proximity and price to vary over time.

## Equal site-period weighting

The weighting comparison preserves the 30/49 school split, the 10,921 sales,
and every existing specification. Models with `did_site_` or `event_site_`
in their names use a sale weight of 1 divided by the eligible transaction
count at that school's site in the same year or half-year. Each observed
site-period therefore contributes total weight one. This is distinct from
the earlier cross-sectional diagnostic, which pooled all 2008–2012 sales
within each site before averaging sites. Counts are recomputed at the time
frequency of the analysis; no sale-price or square-footage weights are used.

The pooled DiDs retain annual or semiannual time effects and omit 2013,
with the corresponding site-period weights. No Census demographic controls
are added. Original transaction-weighted fits remain available unchanged;
the amenity comparison also retains the same baseline distance-by-time terms.

There are 26 empty site-years out of 847 possible cells, and 109 empty
site-half-years out of 1,694. Missing cells have no observable sale price;
they receive neither a zero price nor an imputed observation. Thus equal
weights apply to observed sites within a period, and the contributing site
roster varies over time. The model keeps site fixed effects, but equal
weights alone do not eliminate changing sale composition or selective sales.
Low-volume site-periods receive greater influence than before.

Additional outputs:
- `raw_price_trends.csv`: unadjusted group mean real prices and mean log
  prices, under both weighting schemes and time frequencies, with counts.
- `site_period_support.csv`: full annual and semiannual site-period grids;
  empty cells have zero sales and missing mean prices.
- `raw_prices_annual.png` and `raw_prices_semiannual.png`: the raw means;
  there are no regressions, residualization, or controls in these figures.
- `event_studies_weights_annual.png` and
  `event_studies_weights_semiannual.png`: both weighting schemes overlaid,
  separately without and with housing controls, in dollars and logs.
- `event_studies_weights_amenities.png`: the semiannual hedonic-plus-amenity
  specification under both weighting schemes.

Event-study intervals are pointwise 95% intervals clustered by school site,
with the same finite-sample conventions as before. The pre-period test uses
the site-cluster denominator degrees of freedom. Descriptive raw curves do
not carry confidence intervals. The raw log curve averages log prices,
not the logarithm of the arithmetic mean price.

`report/saved_tables.txt` describes the saved summary tables, verifies their
keys, and records their checksums. It is rebuilt by the normal Make target.
