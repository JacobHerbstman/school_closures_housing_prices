# Download parcel sales

This task downloads Cook County Assessor parcel-sale records for the eight
Chicago townships and calendar years 2006--2025. The raw extract is otherwise
unfiltered so the sample restrictions remain visible in `clean_home_sales`.

Source: Cook County Assessor, [Parcel Sales](https://datacatalog.cookcountyil.gov/resource/wvhk-k5uv).

The output is one row per source record, keyed by `row_id`.
