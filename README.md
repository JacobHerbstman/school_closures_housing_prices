# School closures and housing prices

This project studies how Chicago's 2013 public-school closures affected nearby
home prices, housing-market activity, and neighborhood change. We compare
schools on Chicago Public Schools' (CPS) February 2013 closure-consideration
list that ultimately closed with schools on the same list that remained open.

## Start here

The [sample summary](tasks/audits/home_sample_summary/) shows the analysis
sample: summary statistics, annual and quarterly prices and sales counts, REO
shares, and each school site's prices before and after. The
[price analysis](tasks/audits/home_prices_twfe/) holds the quarter-mile event
studies and pooled difference-in-differences, with variants that drop each kind
of flagged sale. The [logbook](logbook/) records findings and research
decisions.

The study uses a selected group of 30 closed and 49 still-open schools from
the February list. The 30 closed programs exclude 17 whose facilities continued
to house schools. The 49 controls exclude schools with receiving roles or other
recorded actions, including four whose proposed closures were canceled.
These are substantive sample choices, recorded in the school cleaner's roster.

Home sales within one-quarter mile of these schools form the comparison.
We exclude homes near both groups, near schools designated to receive displaced
students ("welcoming schools"), near other schools on the candidate list, and
near buildings that welcoming schools vacated when they moved into a closed
school's building. Each remaining sale enters once, assigned to the nearest
study school of its treatment status. The 30 closed programs occupy 29 physical
sites. Each transaction receives equal weight.

## Data preparation

The [housing tasks](tasks/) assemble Cook County Assessor transactions for
2006–2025, attach property characteristics and historical parcel locations,
and construct the 2008–2018 price sample of houses, townhouses, and
two-to-six-unit apartment buildings. The [sales-cleaning README](tasks/clean_home_sales/)
explains the sale-quality rules: Cook County's three legacy sale flags, removal
of foreclosure auctions and transfers to lenders, required characteristics, and
flags (not removals) for REO resales, quick resales, identical buyer and seller
names, and 1st–99th percentile price tails. Prices are in 2022 dollars.

The [school cleaner](tasks/clean_school_data/) processes 129 schools on the
February candidate list and identifies 127 physical sites. The
[distance task](tasks/calculate_home_school_distances/) measures distances
between homes and school locations; the [exposure task](tasks/build_home_school_exposure/)
records nearby schools for each sale. Broader transaction records remain
available for studying sales activity. Neither price-sample counts nor broader
counts measure turnover without a housing-stock denominator.

## Running the project

From the repository root:

```sh
make setup
make
```

`make setup` checks required tools and installs missing R packages. `make`
compiles the paper draft. To build the sample summary and the event studies
with their inputs, run `make` in `tasks/audits/home_sample_summary/code` and
`tasks/audits/home_prices_twfe/code`. Run `make -C logbook/code` to compile the
research logbook.

## Repository structure

- `data_raw/`: immutable source files and preserved snapshots, excluded from Git.
- `lit_review/`: papers, searchable reading copies, bibliography, and closure-list map.
- `tasks/`: data preparation and analysis, with each task's inputs, code, and outputs in separate directories.
- `tasks/audits/`: exploratory analyses outside the production graph. Earlier
  audits were retired on September 22, 2026 and remain in Git history
  (last present in commit `9762b40`).
- `logbook/`: dated research entries, their frozen exhibits, and their Make build.
- `paper/`: the paper draft and its Make build.

Task Makefiles declare the files needed for each output and build upstream
inputs as needed. See [tasks/README.md](tasks/README.md) for the file conventions.
