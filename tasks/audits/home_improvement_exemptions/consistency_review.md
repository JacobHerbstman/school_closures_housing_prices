# Post-correction consistency review

Reviewed September 2, 2026. Research findings only: no correction values,
production code, or sample restrictions were changed. The original audit
outputs remain the reference calculation, including its original review flags.

## Conclusion

The historical-exemption adjustment is justified, but exact agreement with the
Assessor's helper functions does not establish that every resulting value is
correct. This review identifies repeated source entries that those functions
sum more than once, genuine legacy categories missing from the current
dictionary, and room/bedroom inconsistencies also present in the County's own
post-exemption records. None warrants excluding renovated homes as a group.

The evidence below concerns the broad transaction universe, before final sample
restrictions. It is not a validation of all 9,147 changed transactions or an
estimate of the error rate in the final analysis sample.

## Sources and what they establish

1. [Assessor's HIE documentation](https://github.com/ccao-data/wiki/blob/master/Residential/Home-Improvement-Exemptions.md): legacy improvements were stored separately and incorporated into ordinary characteristics after expiry. Historical modeling should account for active legacy improvements. The documentation distinguishes additive and replacement characteristics; it does not certify individual source records.
2. [Pinned HIE extraction script](https://github.com/ccao-data/data-architecture/blob/33fc006de85317147dbed471e88960048157f1db/etl/scripts-ccao-data-warehouse-us-east-1/ccao/ccao-other-hie.R): selects ADDCHARS rows with `QU_HOME_IMPROVEMENT = 1`, retaining `TAX_YEAR`, upload date, and characteristics. No cross-year deduplication is performed in this script.
3. [Pinned characteristic helpers](https://github.com/ccao-data/ccao/blob/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/R/chars_funs.R): `chars_sparsify()` expands each source year into its active years and sums overlapping additive entries; `chars_update()` adds those totals to baseline characteristics. Identical entries in different tax years are not identified as copies of one event.
4. [Archived County metadata](https://datacatalog.cookcountyil.gov/api/views/bcnq-qi2z) and its [readable API dictionary](https://dev.socrata.com/foundry/datacatalog.cookcountyil.gov/bcnq-qi2z): document residence codes 6--9 and their database grouping under code 5. Rooms are defined as rooms in the property excluding bathrooms; bedrooms are a separate count based on field assessment.
5. [Pinned legacy dictionary](https://github.com/ccao-data/ccao/blob/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/data-raw/vars_dict_legacy.csv), [current dictionary](https://github.com/ccao-data/ccao/blob/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a/data-raw/vars_dict.csv), and [model ingestion](https://github.com/ccao-data/model-res-avm/blob/ced8ac3bb83ba0535cd10910f9eadec89962e937/pipeline/00-ingest.R): legacy labels include 6--9, but the current dictionary omits them. The model's later `vars_recode()` step converts unsupported categories to missing; the inspected code does not explicitly harmonize 6--9 to 5 before that step.
6. [Annual improvement records](https://datacatalog.cookcountyil.gov/Property-Taxation/Assessor-Single-and-Multi-Family-Improvement-Characte/x54s-btds/about_data): retrieved complete available histories for the 26 distinct PINs appearing in the 15 contradictions or the 12 largest absolute square-footage additions. Returned 657 rows, unique by PIN/year/card. All 73 available sale-year comparisons agree with our baseline square footage, rooms, and bedrooms. These are independent API retrievals, not an independent physical survey.
7. [Parcel universe](https://datacatalog.cookcountyil.gov/Property-Taxation/Assessor-Parcel-Universe/nj4t-kc8j/about_data): checked five truncated histories by ten-digit PIN prefix. Returned 81 rows; no successor condominium PINs under those same prefixes were found. That negative result does not establish why the PIN histories end or exclude a successor under a different prefix.

The municipality-hosted county GIS PDF also appeared in search results, but
repeated retrieval and rendering attempts failed. Conclusions here rely on the
successfully retrieved County metadata and source files, not that PDF.

## 1. Legacy residence types: coding meaning resolved

| Legacy code | Meaning | Affected transaction updates |
|---|---|---:|
| 6 | 1.6-story residence | 149 |
| 7 | 1.7-story residence | 178 |
| 8 | 1.8-story residence | 92 |
| 9 | 1.9-story residence | 62 |
| Total | | 481 |

These describe partial livable attics, with the fraction measured relative to
first-floor area. They are not six- through nine-story buildings. The archived
metadata explicitly says the database groups 1.5--1.9-story homes as code 5.
Thus harmonizing those legacy codes to the existing 1.5-story category, while
retaining the original legacy value, has documentary support. No crosswalk has
been implemented in this review.

The initial audit's unknown-code flag reflects its use of the narrower current
dictionary, not proof of bad source data. This resolves the category meanings,
not the factual accuracy or timing of a particular home's exemption. Other
review flags can overlap: 104 transactions have a withheld field other than
residence type. The 481 flags cannot simply be subtracted from 578 to describe
all remaining data-quality issues.

## 2. Fifteen new bedroom/room contradictions

All fifteen have a positive bedroom increment and zero room increment in the
active exemption records. The table shows bedrooms/rooms, not rooms/bedrooms.
The last column is the first tax year after the active exemption(s) expire,
not a value substituted into an earlier sale.

| PIN | Sale year | Baseline beds/rooms | Proposed beds/rooms | First post-expiry record | Finding |
|---|---:|---:|---:|---|---|
| 13292200040000 | 2006 | 2/4 | 5/4 | 2009: 5/4 | Contradiction also in County record; becomes 3/6 in 2021 |
| 25182120110000 | 2008 | 4/6 | 7/6 | 2012: 7/6 | Contradiction also in County record |
| 19184270580000 | 2008 | 2/4 | 6/4 | 2009: 6/4 | Contradiction also in County record |
| 19263180520000 | 2009 | 3/5 | 6/5 | 2012: 6/5 | Contradiction also in County record |
| 19074220140000 | 2010 | 3/5 | 6/5 | 2015: 6/5 | Contradiction also in County record |
| 20321030090000 | 2010 | 3/4 | 5/4 | 2015: 3/4 | Area addition agrees; bedroom addition does not |
| 17204190100000 | 2010 | 2/4 | 5/4 | 2012: 5/4 | Contradiction also in County record |
| 19101160010000 | 2012 | 2/4 | 5/4 | 2018: 5/4 | Contradiction also in County record |
| 19233080230000 | 2012 | 3/5 | 9/5 | 2015: 5/5 | Three identical active entries; counting once gives 5/5 |
| 26321110050000 | 2012 | 2/4 | 6/4 | 2015: 4/4 | Two identical active entries; counting once gives 4/4 |
| 19202100140000 | 2013 | 3/5 | 6/5 | 2015: 4/5 | Three identical active entries; counting once gives 4/5 |
| 19084060530000 | 2014 | 2/5 | 6/5 | 2015: 4/5 | Two identical active entries; counting once gives 4/5 |
| 13263120090000 | 2015 | 1/3 | 4/3 | 2018: 4/9 | Area and bedrooms agree; exemption omitted room increment |
| 19102170020000 | 2016 | 2/3 | 6/3 | 2021: 4/6 | Area agrees; bedroom/room counts do not |
| 19083040550000 | 2017 | 2/4 | 5/4 | 2021: 2/4 | Area and counts remain at baseline; exemption not corroborated |

Four contradictions are explained by repeated entries: counting each identical
active entry once also reproduces the later square footage exactly. This is
strong evidence for a narrow correction to source-event handling, not a reason
to remove those properties. Agreement on the beds <= rooms check alone is not
proof that every room count is complete.

Seven reproduce the County's post-expiry contradiction. Their square footage
also agrees with our proposed additive result. This identifies a problem in the
source counts; it does not establish whether rooms are understated, bedrooms
are overstated, or both. Do not invent rooms by setting them equal to bedrooms.

Four remain partly explained or unresolved. In particular, the 2018 record of
13263120090000 supports an omitted room update, but cannot establish the exact
room total at its 2015 sale. The 2021 values for the final two cases may also
reflect migration or subsequent updates. No future values should be copied
back automatically. PIN 20321030090000 has a repeated entry in 2011 as well,
but that future source year was not active at its 2010 sale and does not explain
that sale's bedroom contradiction.

## 3. Repeated entries: a separate source-data issue

Definition used for this diagnostic: equal PIN, every `qu_*` field (including
upload date), and `hie_last_year_active`; ignore the source tax year and extract
timestamp. This yields 880 groups containing 2,096 rows on 879 PINs in the
countywide source. All repetitions span different source years: 544 groups of
two and 336 groups of three. The finding is not an accidental many-to-many
transaction merge.

To measure exposure, join exemption IDs to the existing transaction/exemption
provenance table, then count repeated signatures within each transaction. There
are 48 eligible pre-2021 single-card sales on 44 PINs with two or more identical
entries simultaneously active. Of those, 47 have a proposed change and eight
already have a withheld-field flag. These 48 are an investigation set, not 48
proven errors or an exclusion list. Similar but nonidentical repeated records
are not covered by this exact-match test.

Example: PIN 19103020160000 has 2009, 2010, and 2011 source rows with the same
January 4, 2010 upload date, 2014 expiry, and 2,082-square-foot addition. For
its 2014 sale the reference procedure produces 2,347 + 3 x 2,082 = 8,593 square
feet. The County's 2015 record is 4,429 = 2,347 + 2,082, with rooms and bedrooms
also agreeing with one addition. This strongly supports counting the repeated
entry once for this case. The parcel is class 212; it is examined here because
this audit intentionally precedes final sample restrictions.

## 4. Twelve largest absolute square-footage additions

Selection: among eligible transactions, rank the absolute added square footage,
take one transaction per PIN (earliest sale year attaining that PIN's maximum),
then inspect the first twelve. This is a review rule, not a proposed size trim.

| PIN | Sale year | Baseline sq ft | Proposed sq ft | Evidence |
|---|---:|---:|---:|---|
| 14081240160000 | 2007 | 7,678 | 15,356 | Source increment exactly equals baseline area, rooms, and bedrooms; residential history ends in 2007. Unresolved potential double count. Parcel was class 314 before becoming 211 in 2006. |
| 19103020160000 | 2014 | 2,347 | 8,593 | Three copies of 2,082; 2015 record is 4,429, agreeing with one copy. |
| 14083080430000 | 2019 | 2,735 | 7,202 | One 4,467 addition; history ends in 2019, before expiry. Unresolved. |
| 25193010130000 | 2011 | 1,330 | 5,320 | Three copies of 1,330; 2015 record is 2,660, agreeing with one copy. |
| 19073260440000 | 2014 | 1,060 | 4,969 | Three copies of 1,303; 2015 record is 2,363, agreeing with one copy. |
| 10363220100000 | 2020 | 3,018 | 6,814 | Different 2018 and 2019 entries, adding 1,191 and 2,605; history ends in 2021, before expiry. Not an exact duplicate; unresolved. |
| 19233080230000 | 2012 | 1,202 | 4,808 | Three copies of 1,202; 2015 record is 2,404, agreeing with one copy. |
| 14203120080000 | 2007 | 2,566 | 5,850 | Different additions of 1,576 and 1,708; ordinary area becomes 4,142 in 2009 and 5,850 in 2012. Area corroborated, but proposed room/bed totals do not fully agree with 2012. |
| 20161060240000 | 2011 | 1,116 | 4,392 | Three copies of 1,092; residential history ends in 2011. Parcel universe changes to class 100 in 2012 and RR in 2013--2015. No post-expiry residential area check. |
| 14053270310000 | 2009 | 4,455 | 7,706 | One 3,251 addition; history ends in 2009, before expiry. Unresolved. |
| 19361190440000 | 2012 | 1,033 | 4,132 | Three copies of 1,033; 2015 record is 2,066, agreeing with one copy. |
| 13063170330000 | 2011 | 1,550 | 4,628 | One 3,078 addition; 2012 record is exactly 4,628, and room/bed additions also agree. |

Thus five large cases have post-expiry evidence of repeated-entry inflation;
two have corroborating area increases; five cannot be resolved from the
retrieved histories. One of the unresolved five also has exact repeated source
entries. Large magnitude alone cannot distinguish a real expansion from a data
error. The available histories do not justify a universal doubling cap or
automatic exclusion of the largest changes.

## Implications, not implemented decisions

- Preserve renovation/exemption information. The overall adjustment remains economically appropriate.
- A legacy residence-type crosswalk is supported; preserve original codes alongside any future harmonized category.
- Investigate exact repeated exemption signatures as administrative copies, retaining all source-row provenance. Do not collapse all overlapping exemptions: the 14203120080000 example supports two distinct additions.
- Treat unresolved room/bed counts and potentially already-incorporated totals as field-level uncertainty. Do not automatically discard the sale or repair counts from later years.
- Before adoption, extend the post-expiry check to the 48 repeated-entry sales and examine other nonidentical overlaps. Resolving these targeted cases would still not constitute a physical validation of every corrected home.
- A focused Assessor inquiry would be useful for the remaining questions: what uniquely identifies one legacy improvement event; whether identical cross-year rows are administrative copies; how omitted room increments and apparent total-versus-increment entries should be interpreted. No inquiry or external message was sent.

## Retrieval and verification record

Read-only source snapshots are retained under
`data_raw/home_improvement_exemptions/`; they are not production inputs:

- `review_improvement_histories.json`: API `https://datacatalog.cookcountyil.gov/resource/x54s-btds.json`, `$where=pin in(...)` using the union of the two tables above, `$order=pin,year,card`, `$limit=50000`. All available fields and years were requested. SHA-256: `cc608ebdf1c4e40d1373d3798c2dc2adf98754a50cd06d2da6ea89e5fbfe0d57`.
- `review_parcel_universe.json`: API `https://datacatalog.cookcountyil.gov/resource/nj4t-kc8j.json`, `$select=pin,pin10,year,class`, `$where=pin10 in('1408124016','1408308043','1036322010','2016106024','1405327031')`, `$order=pin10,year,pin`, `$limit=50000`. SHA-256: `d142e116afd6202533d22b4b4c8033da8c3cacf1e930c19d6f8cca70ba40569e`.
- `legacy_improvement_metadata.json`: `https://datacatalog.cookcountyil.gov/api/views/bcnq-qi2z`.

The correction/reference source versions and baseline SHA-256 values remain
those in this audit's README and source inventory. Byte-level checks confirm
the production characterization script, characterized transaction universe,
cleaning script, and final 2008--2018 sales CSV are unchanged.
