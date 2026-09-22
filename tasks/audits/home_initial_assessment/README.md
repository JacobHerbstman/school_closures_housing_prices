# Initial assessed value and housing-price paths

Controlling for a property's 2006 assessed value does not remove the pre-closure log-price dip. Letting the assessment coefficient vary by year reduces the pooled dollar estimate on the same transactions from $27,769 to $11,301. The log estimate changes from 2.7% to 1.3%. Both pooled confidence intervals include zero. This check addresses whether initially different property values account for the price paths; it does not establish that the recession caused the divergence.

Run `make` from `code/`. The six-page `output/initial_assessment.pdf` shows the annual comparison first, pooled estimates, the effect of restricting to assessment coverage, a specification with all characteristic coefficients varying by year, the initial values of homes sold each year, and numerical results. `assessment_events.png` and `assessment_pooled.png` are standalone figures.

## Source and comparison

The input sales are the preceding hedonic audit's unchanged 11,202 single-family and townhouse transactions within half a mile, 2008–2018. Noah's housing treatment and comparison definitions, sale-quality exclusions, trimming, CPI deflation, site assignments and equal transaction weights remain unchanged. No production task uses this audit.

The new source is Cook County's [Assessor — Assessed Values](https://datacatalog.cookcountyil.gov/Property-Taxation/Assessor-Assessed-Values/uzyt-m557), dataset `uzyt-m557`. The September 21, 2026 extract requests tax year `year=2006` for the 8,235 distinct sale PINs, in batches of at most 500. Each source row is one PIN-year. Original JSON responses, source metadata, requested PINs, exact queries, retrieval time and checksums are preserved in `output/assessments_2006_snapshot.tar.gz`. Downstream estimation and plot changes reuse this snapshot. Changing the acquisition script or input sales explicitly invalidates it; an unchanged build does not contact the API. Failed retrieval or validation occurs before the archive is published.

The covariate is `log(mailed_tot)`: the initial mailed total assessment before appeals, fixed at the 2006 tax year. This predates every sale outcome and the recession. The underlying values are **assessed dollars, not market values**; no assessment-ratio conversion is applied. All observations use the same assessment year, so no CPI conversion is needed for this covariate. The historical extract may incorporate administrative corrections made since 2006; it is not an archived real-time information set.

Sale records join many-to-one to the unique 14-digit assessment `pin`. The join retains all original sale rows to measure coverage. Models with assessments require a positive `mailed_tot`, positive `mailed_bldg`, and a 2006 `class` in 202–210, 234, 278 or 295, matching the current single-family definition. A parcel assessed as land or an apartment building in 2006 does not have a comparable initial single-family house value. No missing assessment is replaced with a later value.

| Coverage, 2008–2018 | Treated sales | Control sales |
|---|---:|---:|
| Existing estimation sample | 1,686 | 9,516 |
| Usable 2006 assessment | 1,541 | 8,911 |
| No 2006 record | 8 | 203 |
| No positive total assessment | 11 | 32 |
| Not single-family in 2006 | 126 | 370 |

This retains 91.4% of treated and 93.6% of control transactions: 10,452 sales of 7,637 parcels at 22 treated and 45 control sites. One control site, Lawndale Elementary Community Academy, has no remaining sale. Of the 496 sales excluded for historical property class, 226 had class 100 (land) and 218 had class 211 (2–6 unit buildings). The remaining cases have other non-single-family classes. These exclusions affect this robustness check only.

## Specifications and findings

Every model includes school-site and calendar-year effects. The existing characteristics are log building and land area and their squares; age and its square; bedrooms, rooms and full bathrooms; and property class, residential type, quality and condition indicators. Standard errors cluster by school site. Annual estimates retain 2013 and use 2012 as the reference. Pooled estimates compare 2014–2018 with 2008–2012, omitting 2013.

Five comparisons separate sample changes from coefficient changes:

1. The existing model on all 11,202 sales.
2. The existing model on the 10,452 sales with usable assessments.
3. The same matched sample, adding one constant coefficient on log initial assessment.
4. The same matched sample, allowing that coefficient to vary by calendar year.
5. The same matched sample, allowing every characteristic coefficient, including initial assessment, to vary by year.

The constant coefficient adjusts for price levels. Year-specific coefficients also allow initially high- and low-value homes to follow different recovery paths. This remains a particular functional-form adjustment; it does not directly measure mortgage distress, neighborhood investment or later renovations.

| Pooled specification | Dollar OLS | Log OLS | PPML |
|---|---:|---:|---:|
| Full sample, existing model | $34,851 | 3.0% | 2.1% |
| Matched sample, existing model | $27,769 | 2.7% | 1.1% |
| Add initial value, fixed coefficient | $28,737 | 3.4% | 1.3% |
| Add initial value, yearly coefficients | $11,301 | 1.3% | 0.02% |
| All premiums vary by year | $6,372 | −1.6% | −1.2% |

The first pooled model uses 10,159 sales; all other pooled models use exactly 9,462. Every pooled 95% interval includes zero. With initial value interacted with year, the dollar interval is [−$18,700, $41,302], the log interval is [−14.2%, 19.6%], and the PPML interval is [−12.1%, 13.9%]. Log and PPML percentages are `100 × (exp(coefficient) − 1)` and concern different conditional outcomes.

The matched-sample 2010 log coefficient changes from −0.237 to −0.220: −21.1% versus −19.7% relative to the 2012 treated-control gap. Its adjusted 95% interval is [−31.5%, −6.0%]. Allowing all characteristic premiums to vary by year still leaves a −19.6% gap. The joint log pre-test p-value rises from 0.025 to 0.086 with assessment-by-year controls, but the remaining dip and wide annual intervals do not establish parallel trends. The all-premiums-by-year dollar model also rejects its joint pre-test (p=0.026).

Among distinct matched parcels, the mean 2006 assessment is $28,594 treated versus $22,375 control; the medians are $17,417 and $15,686. The initial values of the properties sold also change over time. Treated sales in the 2012 reference year have a median 2006 assessment of $26,345, compared with $17,958 in 2010. This is a change in the homes sold, not a change in a home's fixed assessment. Conditioning on initial value still leaves the log-price dip, so observed initial-value composition does not explain it away under this specification.

## Saved evidence

`output/initial_assessment.rds` contains all original sales with assessment match flags, unique parcels, the historical source values, group/year coverage, initial-value distributions, 30 models, 165 treatment coefficients, absorbed terms and source hashes. Reports in `report/` document keys, columns, missingness and distributions. The source response checks verify unique PIN-years, requested PIN coverage, land-plus-building totals and response hashes; model checks require the declared observations and treatment terms. The six full-sample fits reproduce the preceding audit, and PPML convergence and score checks pass. Independent OLS with explicit site/year indicators reproduces the new pooled dollar/log and annual log coefficients.

Disposable acquisition fixtures using the saved responses verify fresh retrieval, unchanged reuse, changed-query invalidation and preservation of the published archive after a failed transfer. A failed fresh retrieval publishes no partial archive. The changed-source dependency reaches estimation, a missing plot regenerates through Make, and unchanged second builds perform no substantive work.
