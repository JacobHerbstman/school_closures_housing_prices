# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/logbook/code")
library(data.table)
support <- fread("../input/site_year_support.csv")
stopifnot(!anyDuplicated(support[, .(school_site_id, sale_year)]))
# Average pre-closure transactions within sites, then weight sites equally.
sites <- support[sale_year <= 2012, .(
  sales = sum(sales), mean_price = weighted.mean(mean_real_price, sales)),
  by = .(school_site_id, treated)]
stopifnot(!anyDuplicated(sites$school_site_id))
comparison <- sites[, .(sites = .N, sales = sum(sales),
  equal_site_mean = mean(mean_price),
  equal_sale_mean = weighted.mean(mean_price, sales)), by = treated]
setorder(comparison, treated)
capture.output(print(comparison), file = "../output/comparison_weights.txt")
