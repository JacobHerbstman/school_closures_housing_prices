# Download residential improvements

This task downloads Cook County Assessor improvement records for every
PIN-year in the master non-condominium residential transaction universe. The
source is improvement-level: a parcel with multiple buildings has one row per
card, so the output key is PIN, year, and card.

The task preserves the Assessor's physical-characteristic fields and does not
choose a primary card, aggregate multiple buildings, impute missing values, or
define hedonic controls. Those are downstream analytical choices. Keying the
request from the master transaction universe also keeps this source extract
independent of later market-sale restrictions.

Source: Cook County Assessor, [Single and Multi-Family Improvement
Characteristics](https://datacatalog.cookcountyil.gov/resource/x54s-btds).

Run `make` from this task's `code/` directory.

The extract is written to `../temp` and moved into `output/` only after every
request succeeds and the key checks pass.

Current snapshot: retrieved September 22, 2026; 406,795 PIN-year-card records
for 399,881 of 399,882 requested PIN-years; SHA-256
`0e96e7699fc58af5d409f1f201407f75f57412d937b56b75cf6de9307ce0fe25`,
byte-identical to the September 7, 2026 extract preserved in
`data_raw/county_snapshots_2026-09-07/`.
