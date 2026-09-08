# Historical home-improvement exemptions

This audit compares two ways to update property characteristics using
home-improvement exemption records: the Assessor's implementation and a
modified version that counts repeated updates once and leaves conflicting
characteristics missing.
The tested method is now independently implemented in production under
`correct_home_sale_characteristics`; `home_sales_finalization` verifies full
parity and documents selection changes. Run `make`
from `code/`; the final product is `output/careful_validation.md`.

The baseline is the 2006--2025 characterized non-condominium, single-PIN
transaction universe, before the downstream market-sale, study-period,
single-card, class-212, completeness, and integrity restrictions. Multicard
transactions remain in the audit but are not corrected.

## Sources

Retrieved 2026-09-02 from the Cook County Assessor's public releases:

- `hie_data.parquet`: the 2026-07-30-ecstatic-carly residential model input,
  S3 version `A.Vx1duMBXlIhnjOQDatleZwljvsFun6`. Contains legacy exemption
  start years 2000--2020, not just the model's publication year.
- `ccao.zip`: [ccao](https://github.com/ccao-data/ccao) commit
  `419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a` (AGPL-3; license inside archive).
- `model_ingest.json`: the GitHub source response for `pipeline/00-ingest.R`
  in [model-res-avm](https://github.com/ccao-data/model-res-avm), commit
  `ced8ac3bb83ba0535cd10910f9eadec89962e937`.
- `improvement_metadata.json`: a snapshot of the public `x54s-btds` metadata.
- `legacy_improvement_metadata.json`: the archived `bcnq-qi2z` dictionary,
  documenting the grouping of legacy residence codes 6--9 under code 5.

Exact download URLs are in this Makefile and the production
`download_home_improvement_exemptions/code/Makefile`, which now owns the shared
HIE, codebook, and legacy-metadata downloads. Raw downloads live unchanged in
`data_raw/home_improvement_exemptions/`; the audit links to them. The source
inventory records SHA-256 fingerprints, including the transaction baseline.

The audit loads the pinned `chars_*` and township functions directly from the
source archive. The only source adaptation removes `ccao::` namespace prefixes
so those calls resolve to the same pinned functions and dictionaries in an
isolated environment. No adjustment arithmetic is changed, and the package's
unrelated AWS and valuation dependencies are not installed.

Required installed R packages are `arrow`, `curl`, `data.table`, `digest`, `dplyr`,
`jsonlite`, `magrittr`, `rlang`, and `tidyr`. The audit fails if one is missing;
it does not modify the production environment-setup task. Package versions
are recorded in the validation result.

## Execution and products

The reference branch runs these linear scripts in order:

1. `inspect_exemption_sources.R`: verify pinned sources and baseline keys;
   write `source_inventory.csv`. `source_sha256.csv` fixes the expected
   fingerprints for the three versioned downloads. The changing metadata
   endpoint is preserved as a local snapshot and fingerprinted separately.
2. `build_exemption_years.R`: reproduce `chars_sparsify()` on the entire
   historical exemption extract. Compare each available update field with an
   independent expansion of the published inclusive active intervals.
   `exemption_years.rds` contains `annual` (unique PIN-year), `membership`
   (unique exemption-year), the raw-source rows with snapshot-specific
   `exemption_id`, the field map, and same-timestamp replacement conflicts.
3. `link_transaction_exemptions.R`: attach annual corrections to the broad
   master. `linked_transactions.rds` contains every original transaction and
   a separate `(row_id, exemption_id)` provenance table. It does not select
   the price sample.
4. `apply_exemption_corrections.R`: call the pinned `chars_update()` and check
   its arithmetic independently. `characteristic_updates.rds` contains all
   original transaction fields, proposed `hie_res_*` values, eligibility and
   uncertainty flags, and a `field_updates` table keyed by transaction and
   baseline field. That table preserves original, reference, and proposed
   values plus the specific source exemption IDs for each update.
5. `validate_exemption_corrections.R`: verify complete baseline preservation,
   cardinalities, active-year provenance, unaffected groups, supported-field
   reference agreement, and synthetic boundary cases. Write `validation.md`.

No production task consumes these outputs. Each generated file has one Make
producer; a second `make` performs only the existing upstream freshness checks.

## Rule-based trial

The trial is separate from the unchanged reference calculations:

1. `apply_careful_corrections.R` writes `careful_characteristic_updates.rds`.
   It counts exact repeated updates once, harmonizes legacy residence codes,
   and marks uncertain corrected fields missing. It keeps every sale and
   original baseline column. No PIN-specific decisions are used.
2. `download_post_expiry_records.R` selects every repeated-entry sale,
   unresolved bedroom/room pair, and the twelve largest original area
   additions (one sale per PIN). It requests the first year after all
   exemptions active at that sale have expired. `post_expiry_records.rds`
   preserves requested keys, returned County card records, query URLs, and
   retrieval time. This is a generated audit extraction; original raw files
   are not edited. No later record feeds the correction producer.
3. `validate_careful_corrections.R` verifies baseline preservation, join keys,
   source provenance, independent arithmetic for every additive field, and
   synthetic timing/duplication cases. It compares the reference and careful
   versions with later single-card records and writes `careful_validation.md`.

An exact repeat has the same PIN, every `qu_*` field (including upload date),
and expiration year. Source tax year and extraction timestamp do not define a
distinct improvement. Only already-active rows participate in a sale's update;
the latest identical occurrence is counted, preserving the reference's
replacement precedence. Different values, dates, or expiry years are not
collapsed. This is a documented event-identification assumption, not proof
that every matching record represents the same physical project.

The trial retains `hie_res_*` as the proposed characteristic names, in its own
RDS. The original `characteristic_updates.rds` remains available for comparison.
Within the trial's `field_updates`, `reference_proposed`, `reference_status`,
and `reference_changed` preserve the first audit's decisions; `proposed`,
`status`, and `changed` describe the trial. `annual_source_value` preserves the
original source total/code; `applied_source_value` records the once-counted
increment or harmonized code. `source_membership` retains all active raw IDs
with a `counted` flag. The field-level contributor lists are generated, not
hand-coded ledgers.

Previously withheld replacement fields now become missing rather than quietly
retaining a possibly outdated baseline. The trial also marks nonpositive area,
negative/noninteger additive counts, and bedrooms exceeding total rooms as
unresolved. For the last check both bedroom and room counts become missing;
the script cannot establish which count is wrong. Checks apply to all eligible
sales, including any preexisting contradiction. Original values remain intact.
`hie_any_withheld_update` now means at least one field has an `unresolved_*`
status. A change to missing counts as `changed`, but the report separately
counts observed corrected values, so these are not mistaken for successful
repairs.

No size cap, percentile trimming, winsorization, backward filling, transaction
exclusion, or manual override is introduced. Large but logically possible
additions and nonidentical overlapping entries remain uncertain where the
sources do not settle them. The post-expiry check does not establish sale-date
truth: subsequent renovations, missing histories, and the 2021 migration can
affect agreement. It never changes a correction or sample membership.

## Reference rules and deliberate limits

- The source start year and township determine active years. Pre-study-period
  exemptions are retained if still active. No future exemption is applied to
  an earlier sale. Start-year sales remain flagged for uncertain within-year
  completion timing; upload dates order competing updates within a start year,
  not sale timing. Across overlapping start-year groups, the latest start
  year's nonzero replacement takes precedence, following the reference.
- Corrections require an active exemption, sale year before 2021, and one
  observed improvement card agreeing with the Assessor's card flags. All
  other rows remain unchanged, including post-2020 records whose source
  characteristics already incorporate HIE changes.
- Additive fields follow the published map: rooms, bedrooms, full/half baths,
  building/land area, and commercial-unit count. Missing baseline totals are
  preserved as missing, while the reference's zero-based arithmetic remains
  visible in `field_updates`; an increment cannot identify a missing total.
- Replacement codes are translated using the pinned variable dictionary.
  Legacy porch code 3 becomes code 0, matching the ingestion script. A winning
  timestamp with conflicting nonzero values, or an unknown replacement code,
  leaves that field unchanged with an explicit review flag. These are audit
  safeguards, not claims about the property's true value.
- Missing class behaves as in the reference: an observed nonzero class can
  still be used; a group without one may remain unresolved. Class 288 retains
  the baseline assessor class. Proposed `hie_res_class` is separate from both
  original `res_class` and sale-record `property_class`.
- `hie_num_active` counts active start-year groups after same-year exemptions
  are combined, not raw exemption records. `exemption_record_count` records
  the latter. Both are retained.
- The export has no renovation-indicator, site-desirability, or condition
  updates. The baseline has no design-type field. The field map records these
  unavailable pairs; they are not inferred or silently filled.
- These reference calculations preserve the Assessor's rules for comparison.
  The production correction task uses the modified rules described above;
  the finalization audit checks their effect on sample eligibility.

The subsequent [consistency review](consistency_review.md) documents legacy
residence codes, all 15 new room/bedroom contradictions, repeated source
entries, and the 12 largest square-footage additions. It leaves this audit's
original correction outputs and flags unchanged.
