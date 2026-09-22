# Build geocoded home sales

This task attaches one historical parcel centroid to each master transaction
using the full residential PIN and sale year. The output,
`geocoded_master_home_transactions_2006_2025.csv`, is one row per transaction
keyed by `row_id`. The join is many-to-one: sales may repeat within a PIN-year,
while the coordinate input must be unique by PIN-year.

The output retains the whole master, including blank coordinates with an
availability flag, independently of every analytical restriction. The
home-to-school distance task reads it; analyses join distances or exposure to
the clean price sample by `row_id`. The task asserts that the join changes
neither row count nor `row_id` order and requires at least 99.9 percent of
transactions to have complete coordinates. Longitude/latitude are EPSG:4326;
projected centroids are EPSG:3435 in US survey feet. Run `make` from `code/`.
