# Quarterly timing and school-site influence

Compare price trends and event studies within half a mile of the existing 30 treated programs and 49 comparison schools, using single-family houses and townhouses sold in 2008–2018. The audit holds the preceding log/levels/PPML estimation sample fixed: 11,202 transactions with complete property characteristics, at 22 treated and 46 control sites. It reads their exact IDs, school assignments and CPI-adjusted prices from `home_price_scale_checks`, then attaches the same characteristics and sale dates by transaction ID. It does not change cleaning or school definitions.

Run `make` in `code/`. `output/quarterly_weights.pdf` contains eight pages: pooled annual estimates, annual event studies, quarterly event studies with and without property controls, quarterly and annual raw prices, quarterly sample/date coverage, and the full quarterly pre-period. Three PNGs provide the main event and raw-price exhibits. `output/quarterly_weights.rds` retains coefficients, model support, adjacent-quarter contrasts, raw means, full site-period grids, volume rankings, date coverage and source hashes. Its data report is written to `report/quarterly_weights.txt` when the data are saved.

## Comparisons

- **Transactions:** weight one for each sale.
- **Equal sites:** weight each sale by the inverse of its site's sale count in that year or quarter. Every observed site-period receives total weight one. Annual and quarterly weights differ. Empty cells have no observable price and receive no imputation, so this is not a balanced panel of sites.
- **Drop top three:** remove every transaction at Buckingham (369 sales), Trumbull (227), and Key (173), retaining transaction weights and all controls. These sites account for 769 of 1,686 treated sales (45.6%). They are also the three busiest treated sites in 2008–2012. Ranking is by transaction volume, not the size or sign of estimated effects. The reduced sample has 10,433 sales and 65 sites; pooled models have 9,452 sales after omitting 2013.

Both time frequencies estimate dollar OLS, log-price OLS, and PPML with school-site and calendar-period fixed effects, with and without the existing property controls. All six annual baseline event models and six pooled baseline models must reproduce the prior coefficients before interpretation. PPML uses price in thousands without rounding, requires convergence, and checks weighted group-period price scores in event models. Standard errors cluster by school site using the existing `fixest` conventions.

Raw arithmetic and geometric means use the same weights. The geometric mean is the exponentiated average log price, not a median. Neither raw series holds the transacting-property mix fixed. Property controls use characteristics observed in the sale year, so they may themselves respond to neighborhood changes.

## What quarterly timing can establish

All event studies include every 2013 observation. Only pooled summaries retain the earlier 2008–2012 versus 2014–2018 comparison, omitting 2013. Annual events retain 2012 as the reference. Quarterly events use **2012 Q3**, allowing the December 2012 utilization-list quarter to have its own coefficient. All quarterly models are estimated on 2008–2018, including when the figure shows only 2011–2015.

The sourced chronology is in `code/timeline.csv`: the December 2012 utilization list is in Q4; February candidates and March proposals share 2013 Q1; the May vote and June school-year end share Q2. Q3 is the first full quarter after June. The academic-year endpoint is not a measured building-vacancy date for each site. Quarter-level prices cannot distinguish the separate events within Q1 or Q2, and many sales in an event's quarter preceded it.

Most earlier dates record a month; most dates from 2013 use a refined instrument date. Neither identifies when the price was agreed. This change in dating and the lag between agreement and completion limit interpretations of abrupt price movements. The coverage page shows the change rather than restricting to refined dates, which would discard nearly all early observations.

Adjacent-quarter contrasts use the full clustered covariance matrix and a t reference with the number of sites minus one degrees of freedom. Intervals are pointwise and unadjusted for multiple comparisons. Event-model joint pre-period tests cover periods before the reference: 2008–2011 annually and 2008 Q1–2012 Q2 quarterly, using an F reference with the site-cluster denominator degrees of freedom. Passing such a test would not establish parallel trends.

## September 15 results

With property controls and annual time effects, the pooled dollar estimate rises from $34,851 (95% interval −$18,377 to $88,079) to $49,499 ($7,889 to $91,108) under equal site-year weights and $58,005 ($2,060 to $113,950) after dropping the top three. Exponentiated log estimates are 3.0%, 23.2%, and 9.6%; PPML estimates are 2.1%, 14.0%, and 10.8%. These checks do not support the explanation that the dollar estimate depends on those three high-volume treated sites.

Quarterly pooled estimates are also saved. Equal site-quarter weighting gives a smaller dollar estimate of $39,129 (−$4,404 to $82,661), compared with $35,365 under transaction weights and $58,937 after dropping the three sites. Changing frequency changes the meaning of equal site-period weights as well as the time effects.

Quarterly event estimates do not cleanly locate a price change in the announcement or closure periods. With controls, all three comparisons' adjacent changes into 2013 Q1, Q2 and Q3 have 95% intervals containing zero for all three estimators. This is not evidence that the effects are small: treated sales number only 30–45 per quarter in 2013, falling to 18–28 after the site exclusions. Across 2008–2018, 405 of 968 treated site-quarters are empty, and 217 of the 563 nonempty cells have just one sale. Equal site-quarter weighting magnifies those thin cells.

The full quarterly pre-period rejects joint flatness in every controlled comparison and estimator (all p-values below 0.01). The original controlled annual log pre-test also rejects (p=0.031), although several other annual tests do not. These diagnostics and the visible pre-period movements remain obstacles to interpreting the positive pooled estimates as causal school-closure effects. The quarterly charts cannot distinguish announcement capitalization from building vacancy, nor does an imprecise coefficient establish no effect.
