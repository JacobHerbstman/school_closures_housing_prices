# School closures and housing prices

This project studies how Chicago's 2013 public-school closures affected nearby
home prices, housing-market activity, and neighborhood change. We compare
schools on Chicago Public Schools' (CPS) February 2013 closure-consideration
list that ultimately closed with schools on the same list that remained open.

## Start with the data

The [data overview](tasks/audits/home_data_overview/) introduces the school
comparison, sample construction, and annual housing trends. Its ten-page
`output/data_overview.pdf` shows the school map, mean and median prices,
price percentiles, sales counts, property types, sample retention, and the
contribution of each school neighborhood. The accompanying `output/data_review.md`
records the cleaning checks and assumptions.

The study uses a selected group of 30 closed and 49 still-open schools from
the February list. The 30 closed programs exclude 17 whose facilities continued
to house schools. The 49 controls exclude schools with receiving roles or other
recorded actions, including four whose proposed closures were canceled.
These are substantive sample choices, explained in the data review.

Home sales within one-quarter mile of these schools form the comparison.
We exclude homes near both groups, schools designated to receive displaced
students ("welcoming schools"), or other schools on the candidate list.
Each remaining sale enters once, assigned to the nearest study school of its
treatment status. The 30 closed programs occupy 29 physical sites. The descriptive
sample contains 11,600 sales during 2008–2018 around those 29 sites and 48 of
the 49 control sites. Missing property characteristics are retained. Each
transaction receives equal weight. Existing regressions use the 10,921-sale
complete-characteristics sample. This is the working cleaning definition adopted
on September 7, 2026. It retains Cook County's three legacy sale filters, including
the deed-type exclusions. The [county-flag audit](tasks/audits/home_sale_quality_flags/)
verifies their implementation and records the exclusions.

Exploratory regressions remain in the [price-analysis audit](tasks/audits/home_prices_twfe/).
The [price-distribution audit](tasks/audits/home_price_distribution/) examines
expensive sales and neighborhood influence. The [distance-band audit](tasks/audits/home_price_rings/)
retains alternative closer/farther comparisons. The [logbook](logbook/) records
findings and research decisions.

## Data preparation

The [housing tasks](tasks/) assemble Cook County Assessor transactions for
2006–2025, attach property characteristics and historical parcel locations,
and construct the 2008–2018 samples of houses, townhouses, and two-to-six-unit
apartment buildings. Descriptive prices retain missing characteristics;
regressions require complete values for their property controls. The [sales-cleaning README](tasks/clean_home_sales/) explains
property eligibility, sale-quality filters, price-per-square-foot exclusions,
and the conversion to 2022 dollars.

The [school cleaner](tasks/clean_school_data/) processes 129 schools on the
February candidate list and identifies 127 physical sites. The
[distance task](tasks/calculate_home_school_distances/) measures distances
between homes and school locations; the [exposure task](tasks/build_home_school_exposure/)
records nearby schools for each sale. Broader transaction records remain
available for studying sales activity. The descriptive price sample
still excludes mixed-use buildings and multiple-building records. Neither
price-sample counts nor broader counts measure turnover without a housing-stock
denominator.

## Running the project

From the repository root:

```sh
make setup
make
```

`make setup` checks required tools and installs missing R packages. `make`
compiles the paper draft. To build the descriptive packet and its inputs, run:

```sh
make -C tasks/audits/home_data_overview/code
```

Open `tasks/audits/home_data_overview/output/data_overview.pdf` first.
Run `make -C logbook/code` to compile the research logbook.

## Repository structure

- `data_raw/`: immutable source files, excluded from Git.
- `lit_review/`: papers, searchable reading copies, bibliography, and closure-list map.
- `tasks/`: data preparation and analysis, with each task's inputs, code, and outputs in separate directories.
- `tasks/audits/`: data checks and exploratory analyses.
- `logbook/`: dated research entries and their Make build.
- `paper/`: the paper draft and its Make build.

Task Makefiles declare the files needed for each output and build upstream
inputs as needed. See [tasks/README.md](tasks/README.md) for the file conventions.
