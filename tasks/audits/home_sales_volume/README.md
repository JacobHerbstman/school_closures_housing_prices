# Sales volume

Does the number of home sales near closed schools change relative to schools
on the February 2013 list that stayed open? Run `make` from `code/`; see
`output/volume.pdf`.

The unit is a school site and year, 2008--2018, for the 29 closed and 48
stayed-open study sites, with zero-sale site-years included. Sales are counted
within a quarter mile of a closed (stayed-open) site and not the other group,
excluding sales near welcoming schools, other February candidates, and
buildings vacated by relocating welcoming schools; each sale counts once, at
its nearest site. Four measures: all market sales in the transaction master
(single-parcel non-condo sales passing the county flags as non-land sales above
$10,000, including foreclosure auctions); the clean price sample; the clean
sample without REO resales; and REO resales. Each is counted for all property
and for single-family homes.

Each measure is also estimated within the baseline price tiers defined in the
price analysis (read from `home_prices_twfe/output/twfe.rds`).

Models are Poisson pseudo-likelihood with site and year fixed effects and
site-clustered standard errors: an annual event study with 2012 as the
reference year and a pooled comparison of 2014--2018 with 2008--2012 (2013
omitted). Coefficients are log changes in expected sales. Site fixed effects
absorb each area's fixed housing stock; there is no parcel-count denominator,
so differential changes in the stock (for example demolitions) are not
separated from changes in turnover. `output/volume.rds` holds the panel, annual
means, and estimates; `report/volume.txt` describes it.
