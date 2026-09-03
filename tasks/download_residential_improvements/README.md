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
