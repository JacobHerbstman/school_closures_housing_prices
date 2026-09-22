# Tract demographic change, 2000 to 2008--2012

Each sale's 2010 Census tract and that tract's change from the 2000 Census to
the 2008--2012 ACS, used by the price analysis to let neighborhoods that were
changing differently before 2013 follow different price paths afterwards. Run
`make` from `code/`.

Sources (fixed releases, retrieved September 22, 2026): 2000 Census SF3 and
2008--2012 ACS five-year tract estimates for Cook County from the Census API
(key read from the ignored project `.Renviron`, never logged); the Census 2010
tract relationship file (`il17trf.txt`); and TIGER/Line 2010 Cook County
tracts. 2000 counts are allocated to 2010 tracts by the share of each 2000
tract's population in the overlap (`POPPCT00`); the ACS is already on 2010
tracts. ACS suppression codes (negative values) are treated as missing.

Measures: change in the share of adults 25+ with a bachelor's degree or more,
in non-Hispanic white and non-Hispanic Black population shares (percentage
points), and in log real mean household income (aggregate household income per
household; 1999 income converted to 2012 dollars with CPI-U annual averages).
Tracts with fewer than 100 adults or households in either vintage have missing
changes. Every geocoded master sale is assigned to its tract by point in
polygon in EPSG:3435. `output/sale_tract_change.csv` is one row per sale keyed
by `row_id`; `report/sale_tract_change.txt` also describes the tract table.
