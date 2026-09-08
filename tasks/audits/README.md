# Audit tasks

Use this directory for diagnostics, validation, robustness checks, and alternative specifications that should remain separate from the production pipeline. Audit tasks follow the same `input/`, `code/`, and `output/` contract as production tasks.

Start with [`home_data_overview`](home_data_overview/): school-source checks,
independent sample reconstruction, and a descriptive packet of raw housing trends.
[`home_sale_quality_flags`](home_sale_quality_flags/) checks the county flags
against the saved source and separates low-price, deed-type, and repeat exclusions.

The current working 30/49 quarter-mile comparison is in
[`home_prices_twfe`](home_prices_twfe/), using equal weight per transaction as the working specification
and equal-site-period weights as a sensitivity check. [`home_school_exposure`](home_school_exposure/) provides exposure and
support diagnostics. [`home_price_rings`](home_price_rings/) retains all closer/farther
annuli, strict any-site overlap exclusions, and common-site comparisons as
alternative specifications. Ring results are not inputs to the working baseline.

[`home_price_distribution`](home_price_distribution/) examines annual price
percentiles, expensive sales, changes in property types sold, and estimates
omitting each school site in turn on the same transaction-weighted sample.
