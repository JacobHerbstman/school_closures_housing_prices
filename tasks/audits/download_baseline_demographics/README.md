# Baseline neighborhood sources

Public Census inputs for the 30/49 school comparison, kept in audits.
Make downloads fixed 2008–2012 ACS five-year estimates and margins of error
for Illinois tracts and block groups, plus 2012 TIGER/Line boundaries.
The Census API requires a key; the official bulk summary files do not.

Sources are the Census Bureau's `acs2012_5yr/summaryfile/` archive and
`geo/tiger/TIGER2012/` archive at https://www2.census.gov/. Exact URLs and
sequence numbers are in `code/Makefile`. Retrieved September 4, 2026.
The downloaded sequence/table lookup and technical documentation describe
column offsets, geographic identifiers, missing values, and 90% margins of error.

Tables: B03002 (race/ethnicity), B15003 (education), C17002 (income-to-poverty ratio),
B19013 (median household income), B23025 (employment), B25002 (occupancy),
and B25003 (tenure). No post-2012 survey observations enter these measures.
2012 income is in 2012 dollars; these are five-year period estimates,
not a December 2012 snapshot or historical annual covariates.

Run `make` from `code/`. Sources remain unchanged in ignored `output/`.
Downloads use a temporary destination and rename only after successful transfer.
Unchanged builds reuse the recorded vintage; updating sources is deliberate.

The project's private Census key is stored only in the ignored root `.Renviron`
with owner-only permissions. R started at the repository root reads it normally.
A task running below `tasks/audits/<task>/code/` can explicitly load it with
`readRenviron("../../../../.Renviron")` and read `Sys.getenv("CENSUS_API_KEY")`.
Never print that value or interpolate it into Make recipes or logged URLs.
The bulk-file build does not require the key. An authenticated API check
independently matched all 2,628 available tract income estimate/MOE cells.
