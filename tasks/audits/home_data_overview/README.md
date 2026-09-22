# Schools, sample construction, and housing trends

Start with `output/data_overview.pdf`: a ten-page descriptive introduction to the school
comparison and the housing records, with no regression adjustment. Run `make`
from `code/`. The PDF and individual PNG figures use the same saved summaries.

The comparison retains the established 30 closed / 49 still-open school roster.
Prices describe each year's transactions, with equal weight per sale. Since
September 22, 2026, every packet uses the production `clean_home_sales` sample
directly (the 2008--2023 file, cut at the packet's end year) rather than
rebuilding the cleaning rules here. That sample removes foreclosure auctions and
transfers to lenders and requires complete characteristics; it keeps REO
resales and other flagged sales. Counts are in `report/`. Annual
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

The sample funnel shows four descriptive stages before the clean sample:
recorded transactions, county flags, non-land sales above $10,000, and eligible
single-card property types. Its final stage is membership in the production
file, which must pass all four. The September 7 descriptive sample that kept
incomplete characteristics was retired on September 22 so that cleaning rules
live in one place. `complete_prices` and
`complete_characteristics_price_trends.png` now equal the main price summaries.

The September 8 radius comparison keeps Noah's school flags and all cleaning
rules fixed. `data_overview_0.125.pdf` and `data_overview_0.5.pdf` contain the
same ten pages at one-eighth and one-half mile. Unsuffixed products retain the
quarter-mile specification for existing consumers. Each alternative has its
own saved summaries, figures, narrative review, and standard data report.
The scripts accept one radius argument in miles (0.125, 0.25, or 0.5).

All geographic exclusions use the chosen radius: treatment-control overlap,
receiving schools, and excluded February candidates. These are cumulative
buffers, not annuli. Each sale enters at most once; same-group overlaps are
assigned to the nearest site. Because exclusions expand with the radius,
the retained samples need not be nested.

The saved `overlap` table counts otherwise eligible descriptive sales near
either study group before geographic exclusions. Its `near_both / near_either`
share measures treatment-control overlap, with each transaction counted once
in the denominator. It is not a percentage of schools or of retained sales.

`late_decline.pdf` investigates the 2016-2018 fall using only the quarter-mile
packet's exact transaction IDs. `late_decline.rds` contains site contributions,
fixed-2016-site-weight means, every single-treated-site omission, price-tail
counts, property-type summaries, monthly coverage, and pre-cleaning site counts.
The decomposition separates changes in site means from changes in sales shares;
it does not measure appreciation of fixed properties. This diagnostic leaves
the adopted transaction weighting and all sample definitions unchanged.

`sales_by_pre_price.png` (also PDF) plots annual sales in fixed lower- and
higher-price school neighborhoods. Each site's 2008-2012 median real sale
price is compared with the common median of site medians across both groups.
Sites at the cutoff enter the lower group. Current transaction prices do not
change a site's classification. Sites without pre-period sales cannot be
classified; the figure states their omitted transaction count. The saved
`pre_prices` and `pre_price_counts` tables record the classification and counts.

`data_overview_through_2023.pdf` extends the quarter-mile packet to 2008-2023.
The scripts take radius and end year as positional arguments; existing packets
use end year 2018. The 2008-2018 rows of the production 2008--2023 clean file
equal the 2008--2018 file, because every cleaning rule is row-level or
within-year. The school roster, locations, exclusion rules, and inflation base stay fixed.
Later school reuse is not treated as a new assignment. The original packet and
existing regressions keep their 2018 endpoint.

The single-family comparison uses 2008–2018 and a quarter-mile radius.
It keeps corrected `analysis_class` 202–210, 234, 278, and 295: houses and
townhouses, excluding apartment buildings. Noah's school flags, geographic
exclusions, and inflation adjustment remain fixed. The restriction is an exact
subset of the broader packet.
`output/data_overview_single_family.pdf` contains the full ten-page packet,
with size and age replacing the apartment-composition page. It contains 3,665
sales (963 treated and 2,702 control). All count stages restrict to corrected
single-family classes; these classifications are available for single-card
records, so the building-card step removes no additional sales. The scripts now take radius, end year, and
property sample (`all` or `single_family`) in that order. The single-family
summaries, review, report, and figures use the `_single_family` suffix.

`data_overview_0.5_single_family.pdf` applies the same single-family rules to
half-mile buffers in 2008–2018. Receiving-school, other-candidate, and opposite-
group exclusions also use half a mile. The packet contains 7,611 sales
(1,211 treated, 6,400 control), compared with 3,665 at a quarter mile. The
wider comparison adds 5,189 transactions and removes 1,243 previously retained
transactions, so these samples are not nested. Thirteen of the 78 school sites
have no retained sales.
The half-mile products use the `_0.5_single_family` suffix.
