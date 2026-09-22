# Recession exposure and the 2012 composition spike

The 2012 spike in treated homes' median **2006 assessed value** largely reflects a shift toward sales near more expensive school sites. Holding each site's share fixed nearly eliminates the spike on the same transactions. This explains that descriptive graph, but the adjusted log-price gap between 2010 and 2012 remains. Independent foreclosure-filing data do not support greater average foreclosure exposure in treated neighborhoods: the control locations have higher rates during the crisis.

Run `make` in `code/`. The seven-page `output/recession_composition.pdf` contains the median comparison, neighborhood shares, foreclosure and seller indicators, property characteristics, alternative reference years, regression checks and a numerical summary. Standalone figures are `median_spike.png`, `recession_evidence.png` and `reference_years.png`.

## Why the median spikes

Every parcel retains its own fixed 2006 mailed assessment. The graph measures the initial value of the houses **sold in each year**, not appreciation in those assessments. There are 99 treated transactions with usable assessments in 2011 and 134 in 2012. The share with assessments above $25,000 rises from 29.3% to exactly 50%. The middle two observations in 2012 are $24,040 and $28,650, giving a median of $26,345. Their transaction identifiers are retained for inspection.

Those 134 sales involve 129 distinct parcels. Five parcels sell twice; four have assessments above $25,000 and one is below. All ten records have distinct deed numbers, and the two sales of each parcel have different recorded dates and prices. These are separately recorded transactions, not duplicate rows to discard. Counting each parcel once in the descriptive distribution lowers the 2012 median to $20,880; the 2011 unique-parcel median remains $16,072. Repeat transactions amplify a composition shift that remains visible among distinct homes. Both series are saved; the working transaction weights are unchanged.

Trumbull, King, Peabody, Duprey/Humboldt and Near North account for 28 of those 99 sales in 2011, versus 66 of 134 in 2012. These are the five largest positive contributors to the change in neighborhood shares. Most of the high-assessment sales come from these sites; a few expensive outliers alone cannot move a median in this way.

| Treated median 2006 assessment | 2011 | 2012 |
|---|---:|---:|
| All matched sales | $16,072 | $26,345 |
| Common sites, observed transaction shares | $16,417 | $29,043 |
| Same common-site transactions, fixed site shares | $16,121 | $16,371 |

Common sites have at least one sale in every year from 2008 through 2013: 14 treated and 34 control sites. Fixed shares come from pooled 2008–2011 transactions, separately within each treatment group. Each site's sales in a year divide its fixed weight equally. The weighted median averages adjacent observations when cumulative weight equals one-half, agreeing with the ordinary median under equal transaction weights. This diagnostic does not replace the working transaction-weighted specification.

On these common sites, the treated mean assessment increases by $7,959 from 2011 to 2012. A symmetric decomposition assigns $6,010 (75.5%) to changing neighborhood shares and $1,949 (24.5%) to different houses sold within neighborhoods. Specifically, the between-site contribution is the change in each site's weight times its average assessment across the two years; the within-site contribution is its average weight times the change in its mean assessment. The two components add exactly to the overall mean change. They are not a decomposition of the median or a causal explanation of transaction selection.

## Why did those five areas have more sales?

The increase reflects more recorded sales after a quiet 2011, but the data do not identify why those owners sold. Annual counts in the assessment-matched sample are:

| School area | 2010 | 2011 | 2012 | 2013 |
|---|---:|---:|---:|---:|
| Trumbull | 21 | 11 | 21 | 15 |
| King | 2 | 3 | 12 | 13 |
| Duprey / Humboldt | 8 | 5 | 13 | 19 |
| Peabody | 5 | 2 | 8 | 6 |
| Near North | 3 | 7 | 12 | 12 |
| **Combined** | **39** | **28** | **66** | **65** |

Trumbull returns to its 2010 count. The other four areas remain busier in 2013 than in 2011. These five sites were selected because their changing shares contributed most to the assessment-mean increase; they are not a prespecified group for testing abnormal sales growth.

The increase survives removing the assessment requirement: the five areas have 32 clean sales in 2011 and 68 in 2012. Before price and county-quality screens, they have 34 and 78 records. That broader comparison still requires eligible geography, single-parcel sales, a single improvement card and single-family classes. It does not count all neighborhood deeds or provide the housing-stock denominator for a turnover rate.

The 28 assessment-matched sales in 2011 involve 27 distinct parcels; the 66 in 2012 involve 63. The 2012 transactions have 65 distinct normalized buyer names and 65 distinct seller names. No exact name appears more than twice on either side. All names are observed in these two years. This does not reveal a concentrated named buyer or seller, although different names can conceal common ownership. The 2012 quarterly counts are 11, 17, 23 and 15, compared with 5, 9, 6 and 8 in 2011. Many dates have month precision, so no exact-day clustering is inferred.

Broad bank/lender-related seller matches rise from four to seven; other known sellers rise from 24 to 59, accounting for 35 of the 38 additional transactions. King accounts for five of the seven 2012 bank-related matches. Explicit corporate-suffix buyers rise from three to ten. These name classifications cannot establish investor intent, verify distress, or identify all related entities.

The houses sold also change. Townhouses, which are included in the working single-family definition, rise from four to sixteen sales: Near North goes from four to ten, Peabody from zero to four, and Duprey/Humboldt from zero to two. Near Duprey/Humboldt, the median recorded building age changes from 121 to 13 years and median area from 968 to 2,082 square feet. These are different homes sold, not physical changes to a fixed set of houses. Only one of the 66 homes sold in 2012 has a recorded construction year after 2006, and that year is 2007. Thus the recorded building dates do not indicate a wave of newly completed 2012 houses in this matched sample; unobserved renovations remain possible.

The broader market was recovering. The Illinois Association of REALTORS' [January 22, 2013 release](https://www.prnewswire.com/news-releases/illinois-sees-home-sales-increases-in-december-2012-notches-229-percent-sales-gain-over-2011-187867161.html) reports that Chicago's 2012 home sales were 22.4% above 2011. That MLS series includes condominiums and is context, not a directly comparable benchmark. Our five selected areas increase much more, while assessment-matched sales at other treated sites decline from 71 to 68. A citywide recovery is a plausible backdrop, not an explanation of the uneven local increase. Seller motivations, mortgage financing and a full parcel denominator are not established by this audit. The adjusted pre-period price gap remains a separate unresolved finding.

`output/site_sales.png` and `output/site_sales.pdf` show all eleven years at the five sites. `output/site_sales.rds` and `report/site_sales.txt` preserve the nested sample counts, parcel and name concentration, quarterly counts, property summaries and input hashes. `investigate_site_sales.R` produces them from the unchanged source vintage without retaining personal names in the saved data or report.

## Independent foreclosure evidence

The new public source is DePaul IHS's [Foreclosure Filings per 100 Residential Parcels](https://www.housingstudies.org/data-portal/browse/?indicator=foreclosures-100-residential-parcel). The September 21, 2026 snapshot contains the 77 Chicago community areas and Chicago Total for 2005–2025. The analysis uses 2005–2018. Original HTML, [City of Chicago community boundaries](https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas/igwz-8jzy), URLs, retrieval time and checksums are preserved in `output/context_snapshot.tar.gz`. Ordinary downstream builds reuse it.

IHS divides filings by residential parcels, multiplying by 100. Its [source description](https://www.housingstudies.org/data-portal/info/foreclosures/) identifies court records obtained through Property Insight and Record Information Services, linked to assessor data, with repeat filings within 180 days removed. A filing begins a foreclosure process; it is not a completed foreclosure. The published rates are rounded to one decimal and cover all residential property types.

Each existing sale point is assigned to exactly one community polygon. Source boundaries arrive in EPSG:4326 and are transformed to EPSG:3435; sale points already use EPSG:3435 feet. Within each group, the area's share of 2008–2011 transactions is held fixed when averaging its annual foreclosure rate. This prevents changes in where our homes sell from creating changes in measured foreclosure exposure.

| Foreclosure filings per 100 residential parcels | Treated locations | Control locations | Chicago |
|---|---:|---:|---:|
| 2008 | 3.85 | 4.76 | 2.9 |
| 2010 | 3.44 | 4.01 | 3.0 |
| 2012 | 3.40 | 3.67 | 2.4 |

These are weighted **community-area exposures**, not foreclosure rates inside the half-mile circles or on the homes sold. They weigh against a simple account in which the treated group had more foreclosure exposure overall, while leaving differences within community areas and in foreclosure timing unresolved. No ecological exposure measure is treated as a parcel-level foreclosure flag.

## Other composition evidence

The audit retains the full 11,202-sale estimation sample and joins the previous seller-name classifications by unique transaction `row_id`. In 2010, broad bank/lender/judicial/GSE seller matches account for 31.0% of treated versus 40.3% of control sales with known names; narrow judicial/GSE/HUD matches account for 4.3% versus 14.2%. These are name proxies, with the previously documented ambiguity around trustees and unrecognized distressed sales. Unknown names are not coded as non-distressed.

The share of sales below $50,000 in 2022 dollars drops from 39.3% to 24.8% for treated sales between 2011 and 2012, while rising from 37.1% to 40.4% among controls. Low prices need not mean distress. Median building size and the townhouse-class share also rise among treated sales in 2012. These are observable changes in the transaction mix.

Buyer names are normalized and flagged only for explicit corporate suffixes such as LLC, INC, CORP, LTD, LLP or LP. This is an organization-name proxy, not an investor classification. It misses individuals and trusts holding investment properties and may include organizations buying for other purposes. It shows no persistent treated excess over 2010–2012. Buyer and seller names are more than 99% observed in the plotted 2008–2013 years. Personal names are not retained in the audit dataset or report.

Consecutive observed pre-closure sales of the same PIN in different calendar years supply only 11 treated pairs ending in 2010 and 21 in 2011. Many observed pairs have large positive price changes. These selected resales, which can include renovations and changes in distress status, do not provide a clean estimate of returns on the neighborhood housing stock. Their changes are not annualized.

## Does this explain the adjusted pre-trend?

The main log specification retains the existing size, age, room, bathroom, class, residential-type, quality and condition controls, site/year effects and school-site clustering. Rebasing it from 2012 to 2008 leaves all fitted values and the joint pre-period equality test unchanged. The negative 2010 point barely changes: −19.9% relative to 2012 versus −18.8% relative to 2008. The latter has a 95% interval of [−34.9%, +1.3%]. The 2010–2012 relative rebound is 24.9%, with an interval of [+8.2%, +44.0%]. Thus the rebound is more clearly estimated than a differential crash measured from 2008. The 2011–2012 relative change alone is +10.2%, with an interval including zero.

Actual removal of 2012 leaves a very similar 2008–2010 estimate of −18.7%; the remaining joint pre-test has p=0.187, which does not establish parallel trends. Allowing seller-category coefficients to vary by year leaves a −23.0% 2008–2010 contrast and a +28.5% 2010–2012 rebound. Removing broad bank/lender-related seller matches and unknown names also leaves substantial movement. Both checks have limitations because the seller proxies do not certify distress and the restriction changes which sales enter.

The two common-site models use exactly 4,919 assessment-matched transactions at 48 sites over 2008–2013. To isolate within-group site mix, the weighted model holds pre-period site shares fixed while preserving each group's actual total number of sales in each year. The estimated 2010–2012 log rebound is essentially unchanged: 26.0% with observed shares and 26.0% with fixed shares. The raw median-assessment spike and the adjusted price gap are therefore distinct findings.

All 68 school sites are omitted individually in the full-sample model. The 2010-versus-2012 point estimate remains between −22.5% and −17.4% across treated-site omissions, and between −20.8% and −18.3% across control-site omissions. No one site eliminates the dip. These are diagnostic estimates, not grounds for choosing exclusions that improve pre-trends.

The evidence explains the assessment-median spike and documents substantial changes in the sales mix. It does not explain away the adjusted pre-period difference or establish the Great Recession as its cause. Recession-related recovery differences remain plausible, including slower recovery among the more distressed controls. That mechanism is not established by these broad area rates and imperfect seller classifications.

## Saved evidence and checks

`composition.rds` contains the original transactions with audited joins, source foreclosure values, fixed area weights, initial-value distributions, school contributions, fixed-share medians, resale pairs and hashes. `model_checks.rds` contains seven specification checks, 122 annual contrasts across reference years, 19 period contrasts and every single-site omission. Standard reports accompany both datasets in `report/`.

Checks preserve all original transaction IDs and prices, enforce unique source keys and complete spatial matches, reproduce the previous baseline and initial-value model, verify the mean decomposition identity, and independently reproduce the fixed-share medians and all seven regression specifications using explicit OLS indicators. The source archive is published only after both downloads validate; failed transfers leave an existing archive untouched. No production cleaning or treatment definition changes.

Frozen-response fixtures check fresh acquisition, unchanged reuse, changed-query invalidation and failure before publication. Changed source dependencies reach both analysis stages, a missing figure regenerates through Make, and unchanged second builds perform no substantive work.
