# What the Seattle paper suggests for the Chicago housing analysis

Read September 21, 2026. The current Chicago comparison is single-family homes
and townhouses within half a mile of Noah's treated and control schools,
2008–2018. This review changes no sample, treatment definition, or estimate.

The evidence does not yet support describing our findings as a precise zero.
With transaction weights and property controls, the pooled log estimate is
3.0%, with a 95% interval from −12.2% to 20.8%. Equal site-year weights and
removing the three busiest treated sites increase the estimates. These results
leave economically meaningful changes possible, while pre-period movements
remain a separate identification concern.

## What Han and Idoux document

Page references below use printed page numbers; PDF viewer pages are one higher.
Source: [November 12, 2025 paper](https://raymondwhan.github.io/JMP_Han.pdf).

| Choice | Documented implementation |
|---|---|
| Transactions | King County Assessor sales, 1999–2023; the price analysis uses single-family homes (pp. 7, 13). |
| Comparison | Within ¼ mile of elementary attendance boundaries. Require more than 10 pre-period sales within 0.1 mile on either side (p. 13). |
| Timing | Pool 2006–2008, 2010–2012, and 2013–2015; omit announcement year 2009 (p. 12). |
| Controls | Age, quadratic floor area, **the property's 2004 assessed value**, stories, bedrooms, bathrooms, waterfront distance, and major-road distance. Coefficients vary by period; boundary-by-period effects and separate distance slopes are included (pp. 12–13, equation 1 and note 21). |
| Outcomes | Boundary regressions use 2010 dollars; the complementary citywide event study uses logs (pp. 14–15, 46–47). These are different comparisons. |
| Composition | Table A.1 makes floor area, age, and bedrooms outcomes; some changes are significant. Table A.2 examines sale counts and permitted units (pp. 60, 62). |

The paper and Appendix D do not specify transaction-level deed exclusions,
foreclosure/investor screens, outlier thresholds, missing-characteristic rules,
or how repeated sales enter. The author's research page links no replication
package. Unreported does not mean unused.

## Our cleaning and the remaining gaps

The [master builder](../tasks/build_master_home_transactions/code/build_master_home_transactions.R)
retains single-parcel transactions and excludes condos and multi-parcel bundles.
The [price cleaner](../tasks/clean_home_sales/code/clean_home_sales.R) applies
the county's three quality flags, requires prices above $10,000 and non-land
sales, and restricts the property class and improvement-card count. The county
same-sale flag concerns repeated **same-price** sales within 365 days; it does
not remove every property that resells. Deed exclusions include quitclaim and
executor deeds, as previously agreed.

We check observed characteristics for inconsistencies, exclude prices above
$5,000 per building square foot, and trim observations strictly above the
within-year citywide 99.9th percentile of nominal price per building square
foot. We do not winsorize. The current single-family packet preserves those
cutoffs from the broader residential cleaning sample. Monthly Chicago all-items
CPI expresses prices in average-2022 dollars. Changing only the constant base
year rescales dollars; it does not resolve differences between logs and levels.

The [overview](../tasks/audits/home_data_overview/code/review_data.R) permits
missing property characteristics, applying plausibility checks where observed.
The current packet contains 11,206 sales; the complete-characteristic models
use 11,202. Thus this completeness restriction currently loses four controls
and no treated sales. This is specific to the half-mile single-family sample.

County flags do not certify that every retained sale is arm's length. We have
not comprehensively excluded related-party transfers, investors, foreclosures,
or short sales. Raw buyer and seller names exist, but company names need not
identify investors, bank names can identify trustees, and name coverage varies.
The [distress audit](../tasks/audits/home_sale_distress/README.md) documents these
limitations. Its proxies are suitable for labeled sensitivities, not automatic
reclassification of every transaction.

The [hedonic models](../tasks/audits/home_price_scale_checks/code/check_price_scales.R)
currently hold characteristic coefficients fixed over time. School-site fixed
effects absorb stable site differences, but do not absorb every property's
unobserved quality. Our earlier initial-price adjustment used a **school area's
mean pre-period transaction price**, on the older quarter-mile all-home sample.
It did not use each parcel's fixed pre-closure assessment. No assessed-value
field is in the current corrected transaction file.

## What the best-practices review adds

Han and Idoux cite [Bishop et al. (2020)](https://www.kellycbishop.com/REEP2020.pdf).
The published review discusses removing noncompetitive transfers, foreclosure
and investment-firm purchases, and clear recording errors. It explicitly says
there is no accepted universal outlier threshold: document restrictions and
assess sensitivity (p. 266). It recommends flexible price functions and allows
characteristic coefficients to vary across time and markets (pp. 265, 269).
It also recognizes selection into observed sales (p. 265, note 10). These
recommendations do not establish that a particular Chicago cutoff or seller
classifier is correct.

## Recommended next checks

1. **Test changes within the single-family sale mix.** Plot floor area, age,
   bedrooms, condition, and improvement indicators by group-year, then estimate
   the corresponding treatment-year contrasts. Report coverage. An apparent
   rise in house quality could reflect different parcels selling, renovations,
   or changed assessor measurement; it is not automatically a confounder.
2. **Allow characteristic price premiums to change over time.** Keep the exact
   sales, geography, weights, and outcomes fixed; interact the existing
   characteristics with year, with pooled periods as a prespecified support
   sensitivity. This asks whether a changing premium for larger or better
   houses explains movements currently attributed to the treatment contrast.
   It does not itself establish parallel trends.
3. **Compare repeat sales of the same PIN.** First report how many parcels and
   sites contribute sales spanning pre- and post-closure. Compare the existing
   model on that restricted sample with a parcel fixed-effect model, separating
   sample selection from the effect of controlling for fixed property quality.
   Check splits, merges, and recorded improvements. Repeat sellers are selected,
   and renovations remain possible; a smaller sample may be less precise.
4. **Check feasibility of a fixed pre-closure parcel value and a stock denominator.**
   Historical assessments require a new validated join and coverage review;
   assessments measured after closure could absorb part of its effect. For
   turnover, retrieve the actual eligible parcel stock: the current coordinate
   download covers sold PIN-years, not all homes at risk of sale.

Keep these as complementary checks, report all prespecified outcomes, and do
not select the preferred model by its significance. A former-attendance-boundary
comparison could separately investigate school assignment, but our distance
buffers measure proximity to a building. Nearby houses on opposite sides may
share building effects and face different reassignment changes; importing the
Seattle boundary design requires a substantive exposure and support audit.

## Reading record

The year-varying-premium and repeat-sale checks were subsequently requested
and run on September 21. Their [results and limitations](../tasks/audits/home_hedonic_dynamics/README.md)
are recorded separately; the recommendations above preserve the reading-stage
assessment. Historical parcel assessments and a stock denominator have not
been added by those checks.

The linked Han PDF retrieved September 21 has SHA-256
`699d01caedf514a65a96f3b5d93cbfc4b12ba27f10259dcf05bc5e97882e1aaf`.
Its `pdftotext -layout` output is byte-identical to the existing
`equilibrium_effects_of_neighborhood_schools.layout.txt`; the existing PDF
has SHA-256 `91e0e9c0fa7df6e7d25e7838ab04eef25860d6559521ab0dfb57f48b5cd60c52`.
The existing source was preserved. PDF byte equality is not claimed.
The Bishop PDF downloaded from the author has SHA-256
`9e833b6da6fd5ba657dc6930c96bcaa703cdae4faf8a5770a085ce22c8356643`.
Downloads and page renders were temporary reading aids. Docling was unavailable;
both papers were converted with `pdftotext -layout`. Han's printed p. 13 and
Table A.1 were checked visually. Code comparison uses the current working tree
based on `e76f4dd`, including the September 15 audits.
