# Why do dollar and log price estimates differ?

This audit examines the existing quarter-mile comparison of 30 closed and 49
still-open schools. It keeps equal weight per transaction and the current
housing-price cleaning. The sample contains 10,921 sales at 29 treated and 48
control physical sites. Run `make` in `code/`.

The audit provides four comparisons:

- Annual means, medians, and the 10th, 25th, 75th, 90th, 95th, and 99th price
  percentiles, separately for treated and control sales.
- The top 1%, 5%, and 10% of prices within each group and year: price cutoffs,
  actual counts, share of total sale value, and contribution to the mean.
  Prices strictly above the R type-7 percentile cutoff enter the upper group;
  ties at the cutoff stay below. Actual fractions can differ from the labels.
  `expensive_sales.csv` lists every sale above the 95th percentile with its
  property type, characteristics, parcel identifier, and nearest school.
- Annual dollar and log DiDs and event studies after omitting each physical
  school site in turn, with and without the baseline housing controls.
  Each sale keeps its original school assignment. No omitted site's sales
  are reassigned to another site. Standard errors cluster by the retained
  school sites; 2012 is the event-study reference and pooled DiDs omit 2013.
- Annual composition and mean prices for houses/townhouses versus class-211
  two-to-six-unit apartment buildings, including composition among expensive
  sales. A descriptive series holds these two property-type shares at each
  group's pooled 2008–2012 shares while using its annual within-type means.
  This isolates the arithmetic role of these shares, not all sale composition.

All prices are in 2022 dollars. The price percentiles and upper-tail labels
are descriptive outcomes, not new sample restrictions or causal quantile
effects. The leave-one-site-out results diagnose influence, not reasons to
remove schools. The range across event-study omissions is a sensitivity range,
not a confidence interval. Omissions change the transactions and neighborhoods
represented and can change both precision and the estimate.

`analysis_sample.csv` saves the eligible transactions and their school
assignments. Its site-year counts must exactly reproduce the baseline audit.
Full-sample refits must reproduce all eight annual baseline models before the
site omissions are accepted. `annual_prices.csv`, `tail_contributions.csv`,
`expensive_sales.csv`, and `property_composition.csv` contain the descriptive
results. `site_omission_coefficients.csv` and `site_omission_models.csv` record
all full-sample and omission estimates, uncertainty, and sample sizes.
Standard reports for the datasets are generated from their saved files
in `report/`.

The figures show the annual price distribution, expensive sales' contribution,
property composition, pooled DiD influence, and event-study sensitivity.
This task consumes local sales, exposure, school records, and baseline audit
outputs through Make-created input links. It feeds the research logbook and
no production analysis.

The upper-tail follow-up splits each group-year into four price bands: at or
below the median, above the median through the 75th percentile, above the
75th through the 95th percentile, and above the 95th percentile. Ties stay in
the lower band. `price_band_periods.csv` pools these annual ranks over
2008–2012 and 2014–2018, recording their contributions to group means and
observed property characteristics. `upper_tail_sites.csv` traces sales above
the annual 75th percentile to school sites over those same periods, including
sites with no upper-quarter transactions. Contributions use all transactions
in the treatment group and period as denominator and sum to the corresponding
upper-quarter contribution to the group mean. These descriptive contributions
are not a decomposition of the regression coefficient.

The initial-price sensitivity check adds interactions between calendar year and
each site's mean 2022-dollar sale price during 2008–2012. The mean pools eligible
pre-closure transactions, gives each transaction equal weight, and remains fixed
across years. Dividing it by $100,000 changes only the units of its coefficient.
The 2012 interaction is omitted because school-site fixed effects absorb the
main effect. Each year has a common linear relationship with initial prices
across treated and control sites; this is not a separate trend for each site.

`initial_price_sites.csv` records the initial means and their transaction support.
`initial_price_coefficients.csv` and `initial_price_models.csv` compare the eight
annual dollar and log models with and without these interactions, preserving the same
sample and site-clustered standard errors. Pooled DiDs exclude 2013, and event
studies use 2012 as reference. Both outcomes use the same initial mean in
dollars, divided by $100,000; the covariate is not logged. Reported standard errors treat the estimated
initial-price covariate as fixed. Initial prices are noisy and partly reflect
which properties sold before closure; this is an exploratory adjustment, not
an adopted replacement for the baseline. `initial_price_events.png` shows the
annual dollar estimates and their pointwise 95% intervals;
`initial_price_log_events.png` shows the corresponding log estimates.
