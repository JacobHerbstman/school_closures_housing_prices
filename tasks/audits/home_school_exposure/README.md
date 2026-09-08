# Home-school exposure audit

This audit checks the quarter-mile exposure measures against the final
2008--2018 non-condo home-sale sample. It does not select an analysis sample or
change the production distance and exposure tasks.

Run `make` from `code/`. The task produces:

- `exposure_summary.csv`: sales and distinct parcels in each focal exposure
  category;
- `treatment_control_summary.csv`: prices, characteristics, timing, and school
  support for treated-only and control-only sales in the full and pre-closure
  periods, both before and after excluding welcoming and other candidate sites;
- `annual_real_price_summary.csv`: annual sales counts, mean real prices, and
  median real prices for the preferred uncontaminated treated and control
  groups;
- `real_price_trends.png`: annual mean and median real sale-price lines for
  those groups;
- `annual_residualized_real_price_summary.csv`: the raw and residualized annual
  mean and median price series underlying the quality-adjusted plot;
- `residualized_real_price_trends.png`: annual mean and median real prices after
  removing differences in observed property characteristics and persistent
  differences across nearest school sites;
- `subannual_residualized_real_price_summary.csv`: semiannual and quarterly
  residualized price summaries for 2010--2017;
- `subannual_residualized_real_price_trends.png`: semiannual and quarterly mean
  and median residualized price lines around the 2013 decision;
- `school_site_support.csv`: quarter-mile sales and parcels around every focal
  treated and control site, including nearest-site and uncontaminated counts;
- `treated_control_overlap_pairs.csv`: the treated-control site pairs assigned
  to the homes inside both rings;
- `competing_exposure.csv`: welcoming- and other-candidate exposure within each
  focal category;
- `radius_sensitivity.csv`: treated-only, control-only, and overlapping counts
  at one-eighth, one-quarter, and one-half mile; and
- `home_school_exposure_map.png`: the clean sales, focal school sites, and
  quarter-mile rings in EPSG:3435.

The preferred uncontaminated rows in the summary tables exclude treated-control
overlap and homes within one-quarter mile of either a welcoming school or a
candidate site outside the 30-treated/49-control comparison. Multiple exposure
to schools with the same treatment status remains visible but is not excluded.

The residualized outcome comes from a pooled regression of log real sale price
on log building and land area and their squares, age and age squared, bedrooms,
rooms, full bathrooms, apartment count, analysis class, residence type,
construction quality, repair condition, and sale month. The residual is
recentered at the sample mean log price and exponentiated to place it on a
common 2022-dollar scale. Nearest-school-site fixed effects absorb persistent
price and amenity differences across the school neighborhoods in the design.
The model includes no year, treatment, or post-period variables, so it does not
mechanically remove the time patterns being inspected. It does not control for
amenities that change over time and remains a descriptive adjustment rather
than an estimate of the closure effect.

The semiannual and quarterly figures use the recorded sale month. Their dotted
line marks the February 13, 2013 candidate list and their dashed line marks the
March 21 closure proposals. These periods are appropriate for exploratory
timing checks, but records without an IDOR-refined date should not support
day-level treatment assignments.

Before the within-year price-per-square-foot trim, the treated arithmetic mean
spike in 2013 Q4 was driven by transaction row `97605224`: a $15,177,429 nominal
sale of a 5,145-square-foot class-211 property. It contributed about 70 percent
of that 79-sale cell's total residualized price; the corresponding median did
not show the spike. The production price sample now excludes this transaction
under the citywide within-year 99.9th-percentile price-per-square-foot rule.
The current figures use the trimmed sample and refit the hedonic model.

## Carver Primary support check

George Washington Carver Primary is the only focal site with no clean
quarter-mile sale. This is not a coordinate or merge error. The cleaned school
record places it at 901 E. 133rd Place, which agrees with the [CPS property
listing](https://propertyleases.cps.edu/ViewAddresses/Index?addressId=359). The
site is inside Altgeld-Murray Homes; the [Chicago Housing Authority describes
the development](https://www.thecha.org/property/altgeld-murray-homes) as a
family public-housing property with 1,971 rowhomes.

An independent query of the Cook County Assessor's 2013 [Parcel
Universe][carver-parcel-query] returned 119 parcel
centroids within 1,320 feet of the school coordinates: 91 exempt parcels, 25
class-100 vacant parcels, one class-202 residential parcel, one class-241
adjacent vacant parcel, and one class-517 industrial parcel. The Assessor's
[class-code definitions](https://prodassets.cookcountyassessor.com/s3fs-public/page_comm/classcode.pdf)
identify class 100 as vacant land. The only standard residential parcel has one
2006 transfer in the [official parcel-sales data][carver-sale-query]:
a single-PIN $120,000 quit-claim deed that the source flags under
`sale_filter_deed_type`. These live-source checks were performed on September
4, 2026. They explain why the broad transaction file contains one nearby sale
but the clean market-sale sample contains none.

The parcel query selected 2013 records inside the EPSG:3435 bounding box
`x = 1,183,466--1,186,106` and `y = 1,815,925--1,818,565`, then retained
centroids satisfying `(x - 1,184,786)^2 + (y - 1,817,245)^2 <= 1,320^2`.
The residential transfer check used PIN `25-34-406-020-0000`.

[carver-parcel-query]: https://datacatalog.cookcountyil.gov/resource/nj4t-kc8j.json?%24select=pin%2Cclass%2Cx_3435%2Cy_3435&%24where=year%3D2013%20and%20x_3435%20between%201183466%20and%201186106%20and%20y_3435%20between%201815925%20and%201818565&%24limit=50000
[carver-sale-query]: https://datacatalog.cookcountyil.gov/resource/wvhk-k5uv.json?%24select=pin%2Csale_date%2Csale_price%2Cdoc_no%2Cdeed_type%2Csale_filter_deed_type%2Cis_multisale%2Cnum_parcels_sale%2Csale_type&%24where=pin%3D%2725344060200000%27&%24order=sale_date

`report/saved_tables.txt` describes the saved summary tables, verifies their
keys, and records their checksums. It is rebuilt by the normal Make target.
