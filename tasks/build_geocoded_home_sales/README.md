# Build geocoded home sales

This task attaches one historical parcel centroid to each master transaction
and each cleaned market sale
using the full residential PIN and sale year. The join is many-to-one: sales
may repeat within a PIN-year, while the coordinate input must be unique by
PIN-year.

`geocoded_master_home_transactions_2006_2025.csv` retains the broad master,
including blank coordinates with an availability flag. It carries original
transaction fields rather than duplicating the full corrected hedonic table.
Use it for future home-to-every-school distances; merge distances back using
`row_id` (or exact PIN-year for a unique centroid). Its definition is independent
of all analytical restrictions.

The task asserts that the join changes neither row count nor `row_id` order and
requires at least 99.9 percent of sales to have complete coordinates. Sales
whose historical parcel record has blank coordinates remain in the upstream
clean-sales file but are excluded from this geocoded-only output and reported
during the build. `geocoded_home_sales_2008_2018.csv` is the complete-hedonic
price sample, one row per geocoded sale keyed by `row_id`. The finalization
audit verifies EPSG:4326 to EPSG:3435 consistency. Distances must use projected
coordinates in explicitly recorded units. Run `make` from `code/`.
