# Sample summary

Exploratory summary statistics and annual and quarterly price plots for the
September 22, 2026 clean sample. Four samples: all property and single-family,
each at a quarter mile and a half mile. A sale is treated (control) if a
closed (stayed-open) site is within the radius and no site of the other group
is; sales within the radius of a welcoming school, another February candidate,
or a building vacated by a relocating welcoming school are excluded. Each sale
is assigned to its nearest site. Every transaction has equal weight.

`output/sample_summary.rds` holds three tables: `summary_stats` (sales,
supporting sites, prices, characteristics, and flag shares by sample, group,
and period: 2008--2012, 2013, 2014--2018); `series` (annual and quarterly
series for all clean sales and for sales without any flag: REO resale, resale
within 365 days, identical party names, 1st--99th price tail); and
`site_prices` (each site's median before and after). `output/sample_summary.pdf`
plots them; its last page shows each site's median before and after. No regression adjustment is applied.
Run `make` from `code/`.
