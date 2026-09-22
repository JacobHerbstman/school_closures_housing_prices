# Audits

Exploratory analyses that read production outputs but never feed them.

- [`home_sample_summary`](home_sample_summary/): summary statistics and annual
  and quarterly descriptive plots for the analysis sample.
- [`home_prices_twfe`](home_prices_twfe/): quarter-mile event studies and pooled
  difference-in-differences, with sale-sample variants and pre-period diagnostics.
- [`home_sales_volume`](home_sales_volume/): quarter-mile sales-volume event
  studies and pooled difference-in-differences (Poisson, site-year panel).
- [`tract_demographic_change`](tract_demographic_change/): each sale's tract
  change in education, race, and income from 2000 to 2008-2012, used as
  neighborhood-trend controls in the price analysis.

Earlier audits (data-overview packets, county-flag and exemption validation,
distance rings, benchmarks, condo recovery, and others) were retired on
September 22, 2026. They remain in Git history, last present in commit
`9762b40`; logbook exhibits drawn from them are frozen in `logbook/exhibits/`.
