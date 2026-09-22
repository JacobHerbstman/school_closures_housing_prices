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

A PIN is a parcel identification number. The task retains only single-PIN,
non-multisale transactions. Multi-PIN sales
cannot be assigned to one physical residential property without additional
judgment. The earlier condo-and-parking recovery pipeline is preserved under
the retired `build_all_home_sales_with_condos` audit (commit `9762b40`) and does not enter the main
cleaning graph.

Buyer and seller names are not used to define the sample. `sale_date` is the
deed date. `is_mydec_date` identifies dates refined to the day using Illinois
transfer declarations (MyDec), almost all sales from 2013. Other dates are the
deed month with the day set to 1 (`sale_date_precision` = `sale_month`). They
are not recording months: the recorder document number encodes the recording
day, and recording falls in the same month (29 percent), the next month (51
percent) or later. Refined dates precede recording by a median of 15 days.
Neither date records when the price was agreed, typically a month or more
before closing. The output is one row per transaction, keyed by the source
`row_id`.
