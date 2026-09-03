# School Closures and Housing Prices

This project studies how the 2013 Chicago public-school closures affected nearby home prices, housing-market activity, and neighborhood change.

The starting identification strategy compares schools that appeared on CPS's February 2013 closure list and ultimately closed with schools on the same list that remained open. That comparison keeps the treated and primary comparison schools inside a common administrative selection screen. The first empirical design should distinguish the candidate-list announcement, the final closure decision, the end-of-year closure, and later site reuse or vacancy.

## Repository structure

- `data_raw/` holds immutable source data. Its contents are ignored by Git.
- `lit_review/` contains the papers, searchable PDF extracts, bibliography, and map assembled for the project.
- `tasks/` contains reproducible units of work. Each analysis task owns `input/`, `code/`, and `output/` directories.
- `tasks/_lib/` is reserved for code genuinely reused across tasks.
- `tasks/audits/` keeps diagnostics and robustness work separate from the production pipeline.
- `paper/` is the final build target.

## Running the project

From the repository root:

```sh
make setup
make
```

`make setup` checks the command-line tools and R packages required by the current repository. `make` builds `paper/paper.pdf`.

Run a task from its `code/` directory. Building the final sales task also builds
its upstream inputs:

```sh
cd tasks/build_geocoded_home_sales/code
make
```

Makefiles are the dependency graph. Inputs passed between tasks should be relative symlinks created by explicit Make rules; scripts should read fixed task-local paths and write fixed task-local outputs.

## Current status

The literature base and a compileable paper entry point are in place. The first
production graph builds a master 2006--2025 Chicago non-condominium transaction
universe, attaches Assessor improvement characteristics, corrects historical
home-improvement exemptions, and resolves property type before constructing
the clean 2008--2018 housing-price sample. Exact historical parcel coordinates
are acquired for the broad master independently of analytical selection.

The primary sample contains market sales of single-card houses, townhouses, and
class-211 two-to-six-unit apartment buildings. It excludes class 212 mixed-use,
requires complete core hedonics and an observed apartment count for class 211,
and does not impose percentile trimming or winsorization. Uncertain correction
fields and contradictory property types remain missing in the broad master;
only the required complete fields determine price-sample eligibility. The
existing numerical integrity exclusions remain fewer rooms than bedrooms and
recorded prices above $5,000 per building square foot. Low-price crash-era sales
remain. Original characteristics and source classes are preserved.

The [housing-side finalization audit](tasks/audits/home_sales_finalization/)
checks correction parity, class changes, sample attrition, price/composition
trends, and coordinates. The final geocoding task also produces a broad
2006--2025 geocoded master for future distances to every school, independent
of the selected price sample. A school-linked analysis sample is still pending
the coauthor's school data.

Condominium recovery, condo characteristics, and the earlier all-home sample
are preserved under `tasks/audits/`; they are not dependencies of the main
cleaning graph. School exposure and boundary construction remain outside this
initial graph.
