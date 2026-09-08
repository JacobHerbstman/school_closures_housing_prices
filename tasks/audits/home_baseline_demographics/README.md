# Baseline demographics around the 30/49 school groups

This audit compares neighborhood characteristics for sales in the
[quarter-mile price sample](../home_prices_twfe/). It assigns homes to Census
tracts and block groups using 2012 Census boundary files (TIGER/Line), then
attaches 2008–2012 American Community Survey (ACS) five-year estimates.

Run `make` in `code/`. Inputs are explicit symlinks to final sales, the geocoded
master, school exposure, and the baseline Census acquisition task. Make downloads the recorded Census files when needed and reuses them on
unchanged builds. Downloaded files are excluded from Git.

Owned datasets:
- `baseline_demographics.csv`: one row per Cook County tract or block group,
  keyed by geography/GEOID. Retains selected source estimates and 90% margins
  of error, derived percentages, and land-based population density.
- `home_census_geographies.csv`: one row per transaction in the existing
  30/49 estimation sample, with tract and block-group GEOIDs. Each home gets
  its own geography; no assignment by school centroid or area-weighted rings.

`demographic_balance.csv` compares baseline characteristics across pre-2013
sales, once weighting transactions equally and once averaging within school
sites then weighting sites equally. Standardized differences divide the
mean gap by the root mean of the two group variances at the corresponding
unit (sale or site). They are descriptive; repeated sales in one tract do not supply independent
demographic measurements. Error bars use 95% percentile intervals from 1,999
bootstrap draws, resampling 29 treated and 48 control sites separately with
replacement (seed 20260904). Each draw recomputes group means and the pooled
standard deviation. The same draws serve both geographies and weight schemes.
Intervals hold ACS estimates fixed; they omit ACS survey uncertainty and
assume independence across sites, including sites sharing a Census geography.
They do not establish causal comparability or account for spatial dependence.
`demographic_balance.png` displays the contrasts. Standard reports describe
saved datasets, key coverage, missingness, and source/output fingerprints.

Income is the neighborhood median household income in 2012 dollars; a mean
of these values is not the pooled residents' median. Black and White shares
are non-Hispanic, Hispanic is any race. Poverty uses people for whom poverty
status is determined (C17002 categories below 0.50 and 0.50–0.99 divided by its total); education uses adults 25+; unemployment uses the
civilian labor force; renting uses occupied units; vacancy uses all housing
units. Shares are 0–100. Density is people per square mile of TIGER land area.
Missing source values and nonpositive denominators stay missing. Income
bottom/top codes are flagged and omitted from numerical income covariates;
source cells remain available. Raw margins of error are retained; they are
not margins of error for the derived ratios or the group comparisons.

These are fixed pre-closure period estimates, not annual demographics.
Tracts give a less granular first comparison; block groups reveal local
variation but can be noisy. ACS residents are not necessarily buyers or
sellers. Baseline poverty/vacancy can describe selection without conditioning
on post-closure neighborhood changes. A future adjustment can interact a
small, prespecified baseline covariate set with calendar time. This audit
prepares and compares covariates; it does not automatically add them to fits.

`report/saved_tables.txt` describes the saved summary tables, verifies their
keys, and records their checksums. It is rebuilt by the normal Make target.
