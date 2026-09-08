# Correct home-sale characteristics

This task updates the recorded characteristics of properties with historical
home-improvement exemptions (HIEs). It retains every transaction in the
2006–2025 non-condominium master, keyed by `row_id`, and supplies corrected
characteristics and property types to the sales cleaner. Run `make` from `code/`.

## Historical exemption correction

The task uses a recorded version of the Assessor's field map and categorical
dictionaries to update 27 characteristics. The
[home-improvement audit](../audits/home_improvement_exemptions/) checks these
calculations against the Assessor's implementation. The correction rules are:

1. Link only exemptions whose inclusive start–expiry interval contains the
   sale year. Correct only single-card sales before 2021; the newer source
   already incorporates these characteristics.
2. Count exact repeated entries once per transaction. Equality requires PIN,
   every `qu_*` field (including upload date), and expiry. Source tax year and
   extraction timestamp are excluded. All raw IDs remain available. Separate
   nonidentical additions are not collapsed.
3. Sum additive increments. A missing baseline total stays missing.
4. Use the latest nonzero replacement, ordered by start year and upload date.
   Conflicting replacements tied on both dates remain missing. Class 288 is
   the exemption, not a replacement property class. A genuinely unresolved
   class does not fall back to the older class.
5. Decode using the Assessor's labels; legacy residence codes 6–9 map to 5
   under the county metadata. Apply the Assessor's porch-code recode.
6. Leave invalid numeric updates and both members of a contradictory
   bedrooms/rooms pair missing. Do not cap large but logically possible
   additions or invent parcel-specific exceptions.

Working characteristics remain `res_*`; their untouched counterparts are
`original_res_*`. The sale source's `property_class` and `property_type` remain
unchanged provenance, not analysis classifications. `hie_exemption_ids` and
`hie_counted_exemption_ids` refer to row numbers in the pinned raw file.
They describe active source membership; `hie_correction_eligible` states
whether those records were actually eligible for use. `hie_unresolved_fields`
lists fields left unknown. `hie_start_year_timing_uncertain` marks sales in the year an exemption began.
The annual records do not establish whether the improvement preceded the sale;
these sales remain eligible for correction.

## Consistent property type

`analysis_class` starts with the corrected, same-year improvement `res_class`.
It is missing when observed characteristics contradict the class:

- single-family classes 202–210, 234, 278, or 295 with multiple apartments or
  multifamily use;
- class 211 with no apartments or single-family use.

`analysis_property_type` is derived from that resolved class: single-family,
two-to-six-unit, or class-212 mixed-use. Missing use alone does not exclude a
sale. Missing apartment count is handled by the downstream class-211
completeness rule. Class-specific size bands are not used for trimming.

A coherent 211-to-single-family update therefore no longer triggers a
class-211 apartment-count requirement. A contradictory update remains in the
master, with unknown analysis type, rather than receiving a guessed type.
The rule applies equally to HIE-corrected and uncorrected records.

Later records are only audit evidence. They cannot establish conversion dates
or be copied backward. See `tasks/audits/home_sales_finalization/` for full
production/reference parity, class follow-up, sample reconciliation, and
coordinate checks; see the original HIE audit for source-method validation.

The normal build also writes a standard data report in `report/`, including
the saved CSV checksum, transaction key checks, missingness, and distributions.
