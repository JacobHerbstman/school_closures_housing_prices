# Audit residential multicard improvements

This audit examines every non-condominium sale PIN-year with more than one
Assessor improvement card. It records card counts, square-footage concentration,
repeated physical profiles, card-class differences, and the usefulness of the
Assessor's proration fields. It also reports how frequently these PIN-years
appear in the clean market-sale sample.

The audit does not choose a main card, sum characteristics into a production
record, or exclude sales. That restraint matters because the card-proration
field is usually zero and card 1 is not always the largest building. Cook
County's residential AVM avoids this ambiguity by training only on
single-building PINs; that is a useful benchmark, not an automatic rule for
this project's unadjusted transaction sample.

The audit supports a conservative downstream sequence: retain multicard sales
in the unadjusted transaction and market-activity samples; use single-card sales
for the baseline non-condo hedonic specification; and treat any construction of
multicard hedonic totals as a later sensitivity. A sensitivity should not sum
cards mechanically because some classes repeat the same physical profile across
several cards.

Source documentation:

- [Cook County residential AVM](https://github.com/ccao-data/model-res-avm)
- [Single and Multi-Family Improvement Characteristics](https://datacatalog.cookcountyil.gov/resource/x54s-btds)

Run `make` from this task's `code/` directory.
