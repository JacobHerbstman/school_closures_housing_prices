# Download parcel sales

This task downloads Cook County Assessor parcel-sale records for the eight
Chicago townships and calendar years 2006--2025. The raw extract is otherwise
unfiltered so the sample restrictions remain visible in `clean_home_sales`.

Source: Cook County Assessor, [Parcel Sales](https://datacatalog.cookcountyil.gov/resource/wvhk-k5uv).

The output is one row per source record, keyed by `row_id`.

The script assembles the extract in a temporary directory and publishes it
only after the row count and CSV structure checks pass, so a failed transfer
leaves the previous snapshot in place. Run `make` from `code/`.

Current snapshot: retrieved September 22, 2026; 1,021,374 records; SHA-256
`026714c327576c569ab82d61704c09d94fa7ba57e9be777ea18224a104fcc65e`. This is
byte-identical to the September 7, 2026 extract preserved in
`data_raw/county_snapshots_2026-09-07/`.
