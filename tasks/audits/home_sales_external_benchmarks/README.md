# Home-sales external benchmarks

This audit checks whether the cleaned Chicago sales series has plausible
levels, cycles, and composition. It is diagnostic only and is not an input to
the production sales pipeline.

The audit produces three figures and four reusable tables. It compares:

- annual Chicago transaction counts and nominal median prices;
- annual transaction counts, prices, composition, sample retention, condo
  parking recovery, and transaction-date precision within the project data;
- monthly year-over-year price and sales-count changes;
- Zillow's Chicago city median sale price and Home Value Index;
- Chicago transaction counts against Zillow's Chicago metropolitan-area
  sales-count index; and
- 2024 transaction composition and median price against the ACS owner-occupied
  housing stock.

The activity check also reports the former warranty/trustee and buyer/seller
name restrictions as an audit-only sensitivity. The production sample relies
on Cook County's published quality flags and does not impose either additional
restriction. The production series includes verified two-PIN condo-and-parking
transactions; the audit separately records their annual contribution and checks
that the remaining observations reproduce the single-PIN funnel after accounting
for condo PINs whose Assessor characteristics do not verify a livable unit.

Outputs:

- `annual_home_sales_benchmarks.csv`: annual internal and external series;
- `monthly_home_sales_benchmarks.csv`: monthly internal and Zillow series,
  rolling measures, and year-over-year changes;
- `home_sales_composition_2024.csv`: the Chicago-sales and ACS stock
  composition comparison;
- `home_sales_external_correlations.csv`: Pearson and Spearman correlations
  with periods, transformations, sample sizes, and comparison-specific caveats;
- `home_sales_descriptive_dashboard.png`: the internal descriptive suite;
- `home_sales_external_benchmarks.png`: annual Zillow and ACS comparisons; and
- `home_sales_monthly_benchmarks.png`: monthly Zillow comparisons and growth
  scatterplots.

The comparisons are not definitions of the analysis sample. Zillow's Home
Value Index measures the value of the middle of the housing stock, ACS values
are reported for owner-occupied units, and the Zillow sales-count series covers
the metropolitan area rather than Chicago city. The composition comparison is
also stock versus flow: ACS counts housing units, whereas class 211 sales are
transactions in two-to-six-unit buildings.

Correlations in levels are reported because they make gross discrepancies easy
to see, but they are not strong validation: trending series can be highly
correlated even when their short-run movements differ. The annual and monthly
growth correlations are the more informative checks. Neither comparison should
match mechanically because the underlying samples and, for sales counts, the
geographies differ.

Sources:

- [Cook County Assessor parcel-sales metadata](https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv)
- [Zillow Research housing data](https://www.zillow.com/research/data/)
- [2024 ACS table-based Summary File](https://www.census.gov/programs-surveys/acs/data/summary-file.2024.html)

Run `make` from this task's `code/` directory.
