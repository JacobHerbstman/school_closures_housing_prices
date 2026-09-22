# Housing-price event studies and difference-in-differences

Event studies and pooled difference-in-differences comparing home prices near
the 30 closed programs (29 sites) with the 49 schools on the February 2013 list
that stayed open. Run `make` from `code/`; start with `output/event_studies.pdf`.

The observation is a transaction in the production 2008--2018 clean sample.
Two samples, all property and single-family, within a quarter mile (1,320
feet). A sale is treated (control) when a closed (stayed-open) site is within
the radius and no site of the other group is; sales within the radius of a
welcoming school, another February candidate, or a building vacated by a
relocating welcoming school are excluded. A sale near several sites of its
group uses the nearest one for its site fixed effect and cluster.

The outcome is log real price (2022 dollars). Every model has school-site and
sale-year fixed effects, equal weight per transaction, and standard errors
clustered by site. The event study uses 2012 as the reference year and shows
2013 as a transition year; the pooled estimate compares 2014--2018 with
2008--2012 and omits 2013. Two control sets: fixed effects only, and hedonics
(log building and lot area and age, each with its square; beds, rooms, full
baths; residence type, construction quality, repair condition; REO and
quick-resale indicators; a two-to-six-unit indicator). A unit-count factor with
an unknown level changed no estimate by more than 0.003 log points and is not
carried. Five sale-sample variants: all clean sales, and dropping REO resales,
resales within 365 days, sales outside the within-year 1st--99th price
percentiles, or all flagged sales.

Baseline price tiers split the comparison: each study site's 2008--2012 median
real price among all clean sales within a quarter mile, cut at the median of
site medians across both groups (14 closed / 25 stayed-open lower-price sites,
15 / 23 higher-price). Tier models are estimated separately within each tier for
all clean sales and without REO resales. The tiers are saved in `twfe.rds` for
the sales-volume audit.

Property-class dummies are not used: classes 205/207 and 210/295 change at age
62. `output/twfe.rds` holds
the coefficients, model summaries (including the joint 2008--2011 pre-trend
test), and site-year support; `report/twfe.txt` describes it. These are prices
conditional on sale in repeated cross sections. Outputs cited by logbook entries
before September 22, 2026 are frozen in `logbook/exhibits/home_prices_twfe_2026-09-09/`.
