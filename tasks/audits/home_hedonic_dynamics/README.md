# Changing house-characteristic premiums and repeat sales

These checks use the current 2008–2018 half-mile single-family and townhouse
comparison. Noah's school definitions, geographic exclusions, price cleaning,
CPI adjustment, and transaction weights are unchanged. Run `make` from `code/`.
The six-page `output/hedonic_dynamics.pdf` presents pooled estimates, annual
events, repeat-sale support, and a sensitivity excluding recorded changes.

## Comparisons

The task reads the exact 11,202 complete-characteristic transactions, prices in
2022 dollars, and school assignments saved by `home_price_scale_checks`. It
joins corrected characteristics and PINs by unique `row_id`, checking complete
coverage. The broader descriptive packet has four additional control sales
with incomplete characteristics; this audit keeps the existing model sample.

1. **All sales, fixed premiums:** reproduce the preceding controlled models.
2. **All sales, premiums varying by year:** interact the entire existing
   characteristic block with calendar year. The transformations are unchanged:
   log building/land area and their squares, age and its square, bedrooms,
   rooms, bathrooms, class, residence type, construction quality, and condition.
   This allows category premiums as well as continuous slopes to vary. Site
   and year fixed effects remain. No observation is added or dropped.
3. **Repeat sales, site effects:** retain parcels with at least one eligible
   sale in 2008–2012 and another in 2014–2018; use the existing specification.
4. **Repeat sales, parcel effects:** on exactly that subset, replace site
   effects with parcel effects, retaining year effects and fixed characteristic
   coefficients. Site effects are absorbed by parcel effects because assignments
   are constant within PIN. There is no arbitrary first/last sale pairing.
5. **Stable records, site effects**, and **stable records, parcel effects:**
   repeat the last two models after excluding repeat parcels with any observed
   change in a controlled characteristic or an improvement record. Improvement
   means `hie_correction_eligible` or `res_char_renovation == "Yes"` in any
   included transaction. This is a sensitivity, not a revised primary sample.

All comparisons estimate dollar OLS, log-price OLS, and PPML. Annual events
retain 2013 and normalize to 2012. Pooled estimates omit 2013 and compare
2014–2018 with 2008–2012. All intervals cluster by school site, including the
parcel-effects models. Redundant controls absorbed by fixed effects or absent
categories are recorded in `dropped_terms`; no treatment terms are dropped.
PPML uses thousands of dollars for numerical scaling without rounding.

## Results, September 21, 2026

Pooled estimates below are differences in 2022 dollars or
`100 × [exp(coefficient) − 1]`. The latter describes different objects for log
OLS (conditional log prices) and PPML (conditional mean dollar prices).

| Comparison | Dollar OLS, 95% interval | Log OLS, 95% interval | PPML, 95% interval |
|---|---|---|---|
| All sales, fixed premiums | $34,851 [−$18,377, $88,079] | 3.0% [−12.2%, 20.8%] | 2.1% [−7.6%, 12.7%] |
| All sales, premiums by year | $18,541 [−$15,750, $52,831] | −1.2% [−12.9%, 12.2%] | 1.3% [−7.8%, 11.4%] |
| Repeat sales, site effects | $12,269 [−$48,195, $72,732] | −6.0% [−25.5%, 18.6%] | −5.7% [−14.6%, 4.1%] |
| Repeat sales, parcel effects | −$1,505 [−$51,068, $48,059] | −9.0% [−27.2%, 13.8%] | −7.5% [−15.7%, 1.5%] |
| Stable records, site effects | −$2,808 [−$56,516, $50,899] | −5.6% [−25.5%, 19.6%] | −6.1% [−14.4%, 3.0%] |
| Stable records, parcel effects | −$4,718 [−$56,277, $46,841] | −7.9% [−25.9%, 14.4%] | −6.6% [−14.2%, 1.6%] |

The annual full sample contains 1,686 treated and 9,516 control sales at 68
sites. The pooled full sample has 10,159 sales. Repeat sales span 132 treated
parcels at 17 sites and 630 control parcels at 38 sites, contributing 1,808
annual-model transactions (318 treated, 1,490 control). Omitting 2013 leaves
1,778 transactions (310 treated, 1,468 control). Annual treated counts range
from 20 to 41 outside 2013; only eight occur in 2013.
Because parcels qualify through pre-2013 and post-2013 sales, a 2013 sale
must be an additional transaction. The selected sample's 2013 count dip
must not be interpreted as evidence of a closure-induced market slowdown.
In the full estimation sample, treated counts are 141, 156, and 154 in
2012, 2013, and 2014; control counts are 712, 887, and 871. Both groups
have more sales in 2013 than in 2012. The support exhibit now places these
counts above the selected repeat-sale counts and leaves the additional 2013
repeat sales as isolated points, making the selection rule visible.

Among repeat parcels, 25 treated and 68 control parcels have changes in at
least one controlled characteristic; 14 treated and 49 control parcels have
an improvement record. These sets overlap. The stable-record sensitivity
retains 99 treated and 534 control parcels at 53 sites, with 1,478 annual-model
transactions or 1,458 after omitting 2013.

Allowing premiums to vary lowers the dollar estimate by about 47%, without
changing the sample. This demonstrates sensitivity to how characteristics
are priced over time; it does not establish that any particular characteristic
or foreclosure recovery caused the earlier dollar estimate. The 2010 log
coefficient remains −0.210 relative to 2012 (95% interval −0.369 to −0.050).
The joint annual log pre-test changes from p=0.031 to p=0.121, which does not
establish parallel trends. Stable-repeat dollar events reject the joint
pre-test (p=0.019), another reason not to treat that subset as a clean design.
In the stable-record parcel-effects log model, the 2011 coefficient translates
to −40.8% relative to 2012 (95% interval −60.0% to −12.4%). Its joint
pre-test is p=0.068. Wide intervals and non-rejecting joint tests in smaller
samples do not establish that economically large pre-period movements are
absent. These models remain diagnostics rather than credible evidence of a
causal zero.

For repeats, part of the change arises from selecting the subset: even the
site-effects model has a smaller dollar estimate. Parcel effects lower it
further. This is not a decomposition of bias and does not prove a zero effect.
The annual dollar event study still shows a late rebound relative to the 2012
trough: the repeat-parcel estimate for 2018 is $98,281 [95% interval $23,346,
$173,216]. But 2008 is also $102,432 above the 2012 reference [$18,855,
$186,010]. A small pooled pre/post contrast therefore does not mean every
annual coefficient is near zero or that the difference between logs and
levels has disappeared.
Requiring post-closure resale selects on a possible treatment outcome; fewer
sites contribute, and annual comparisons are imprecise. Unchanged PIN and
characteristic records cannot rule out unrecorded renovations, demolition and
rebuilding, or parcel changes; historical splits and merges are not separately
linked here. Excluding recorded changes can also condition on post-treatment
outcomes. Current characteristics themselves may reflect treatment mechanisms.

## Outputs and verification

`output/hedonic_dynamics.rds` contains the transaction sample and selection
flags, parcel and site support, annual counts, all 198 treatment coefficients,
36 model summaries, collinear-term records, and source hashes. The standard
report is written to `report/hedonic_dynamics.txt` when the RDS is saved.
`pooled_comparisons.png`, `controls_by_year.png`, `repeat_sales.png`, and
`sample_support.png` are the main exhibits; the PDF also contains a
sensitivity page.

All six baseline fits reproduce the preceding estimates and standard errors.
All fits retain their intended observations and treatment terms. All PPML
fits converge and satisfy the group-year or group-period price-total score
checks. Separate OLS fits with explicit dummy variables reproduce the six
new pooled dollar/log coefficients for the year-varying model and the two
parcel-effects samples (largest absolute coefficient difference below
0.000001). Repeated parcels have pre- and post-period support after omitting
2013. The Make build, unchanged second build, and rendered exhibits were
checked. Source data and existing analysis products remain unchanged.
