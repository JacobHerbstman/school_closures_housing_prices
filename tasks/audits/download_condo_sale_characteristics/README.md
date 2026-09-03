# Download condo sale characteristics audit

This task downloads historical condominium characteristics for condominium
PIN-years that appear in the parcel-sales source. It retains the source fields
needed to distinguish livable units from parking, storage, and common areas;
allocate verified condo-and-parking bundle prices by ownership share; and build
basic unit and building hedonic controls.

Source: Cook County Assessor, [Residential Condominium Unit Characteristics](https://datacatalog.cookcountyil.gov/resource/3r7i-mrz4).

The output is one row per returned condominium PIN-year. Unit characteristics
are sparse historically: Cook County began compiling square footage, bedrooms,
and baths from listings and other sources in 2021. Missing historical PIN-years
are reported during the build and remain in the immutable parcel-sales source;
they cannot qualify for the verified condo-and-parking rule.

Cook County's condo AVM trains on livable single-PIN condo sales and selected
two-PIN unit-and-garage bundles. For the latter, it keeps the unit when exactly
one PIN is a garage and the unit ownership share is at least three times the
garage share, then allocates the recorded bundle price by relative ownership.
This repository applies that transaction rule in `build_master_home_transactions`.
It does not copy the AVM's sale-derived rolling-price features into this source
task.
