# Schools, sample construction, and housing trends

Start with `output/data_overview.pdf`: a ten-page descriptive introduction to the school
comparison and the housing records, with no regression adjustment. Run `make`
from `code/`. The PDF and individual PNG figures use the same saved summaries.

The comparison retains the established 30 closed / 49 still-open school roster.
Prices describe each year's transactions, with equal weight per sale. The
11,600-sale descriptive sample includes transactions with missing characteristics,
including blank apartment-unit counts. The earlier complete-characteristics
sample contains 10,921 sales and remains the input to existing regressions. Annual
counts also show market-screened transactions before the property-eligibility and price
restrictions. Counts are not turnover rates: no housing-stock denominator is used.

Inputs are the supplied school rosters and report cards, the corrected transaction
master, the clean price sample, historical parcel locations, the production
school exposures, and Chicago CPI. This task independently reconstructs price
selection and geographic assignment, checks school locations and roster coding,
and records sample attrition and changing property composition. It does not
read coefficients, fitted values, or event-study outputs.

`output/data_review.rds` holds the checked school roster, sale attrition, annual
price distributions, property-type summaries, and site support. Standard data
reports are in `report/`. `output/data_review.md` explains findings and assumptions.
The county-flag step is checked and decomposed in
`tasks/audits/home_sale_quality_flags/output/sale_flags.md`.
School status is also checked against Appendix A of the Consortium's 2015
*School Closings in Chicago*, acquired by the school-source task. The original
manual roster remains the production coding source; published-program closure
and continued use of a building are separate concepts.

The original CPS February list is preserved in a contemporaneous ABC news PDF.
`code/candidate_reference.csv` transcribes all 129 displayed names and records
their correspondence to the supplied roster. `code/school_reference.csv`
transcribes the 47 closed programs and their receiving schools from Appendix A,
printed pages 41–43. Fifteen entries explicitly identify receiving schools moving
into closed facilities; CPS notices document the two additional preexisting
co-locations (Fermi/South Shore and Garfield Park/Faraday). These files verify the
supplied coding; they do not replace it. Individual final board reports for all
other school actions have not all been reverified. Source URLs and file hashes
are recorded in the review. The map uses the city's hydrography file for context.

The September 7 review read all 103 existing script/build files, including
archived analyses. Runtime checks focus on the current data and school comparison;
archived acquisitions are not refreshed. The separate housing-finalization check
can retain its recorded follow-up vintage with
`make -o ../output/class_followups.rds -W reconcile_samples.R` in that task's
`code/` directory. This requires the existing follow-up snapshot.

For descriptive trends, the existing property-eligibility and sale-quality rules
remain. Room consistency is checked when both counts are observed. The existing
citywide annual price-per-square-foot cutoffs are held fixed and applied only
when positive floor area is available. Missing characteristics alone never
exclude a sale. Means of building size use available positive floor area;
dollar-price summaries retain all selected sales. The saved `complete_prices`
table and `complete_characteristics_price_trends.png` preserve the original
figure used by the earlier logbook entry.
