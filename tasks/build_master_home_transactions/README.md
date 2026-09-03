# Build master home transactions

This task constructs a master non-condominium residential transaction universe
from the raw Cook County parcel-sales extract. It retains classes 202--212,
234, 278, and 295. These cover houses, townhouses, two-to-six-unit buildings,
and small mixed-use residential buildings. Class 212 remains labeled as
mixed-use so the cleaning task can exclude it explicitly. See the Assessor's
[property-class definitions](https://prodassets.cookcountyassessor.com/s3fs-public/form_documents/Class_codes_definitions_12.16.24.pdf).

The master file does not apply Cook County's sale-quality flags, the $10,000
minimum, or the non-land restriction. Those analytical restrictions belong to
the downstream `clean_home_sales` task and remain observable here.

The task retains only single-PIN, non-multisale transactions. Multi-PIN sales
cannot be assigned to one physical residential property without additional
judgment. The earlier condo-and-parking recovery pipeline is preserved under
`tasks/audits/build_all_home_sales_with_condos` and does not enter the main
cleaning graph.

Buyer and seller names are not used to define the universe. `is_mydec_date` is
retained because unrefined `sale_date` records should not be used for day-level
treatment timing. The output is one row per transaction, keyed by the source
`row_id`.
