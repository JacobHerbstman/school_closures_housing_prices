# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
library(data.table)
sales <- fread("../output/analysis_sample.csv", colClasses = c(row_id = "character", pin = "character"))
stopifnot(!anyDuplicated(sales$row_id))
annual <- sales[, .(sales = .N, sites = uniqueN(school_site_id), mean_price = mean(sale_price_real_2022),
  geometric_mean = exp(mean(log_real_price)), median_price = median(sale_price_real_2022),
  p10 = quantile(sale_price_real_2022, .10, type = 7), p25 = quantile(sale_price_real_2022, .25, type = 7),
  p75 = quantile(sale_price_real_2022, .75, type = 7), p90 = quantile(sale_price_real_2022, .90, type = 7),
  p95 = quantile(sale_price_real_2022, .95, type = 7), p99 = quantile(sale_price_real_2022, .99, type = 7)),
  by = .(treated, sale_year)]
# A group's annual upper tail is a descriptive ranking, not an exclusion rule.
sales[, top5 := sale_price_real_2022 > quantile(sale_price_real_2022, .95, type = 7), by = .(treated, sale_year)]
tails <- list()
for (fraction in c(.01, .05, .10)) {
  tails[[as.character(fraction)]] <- sales[, {
    cutoff <- quantile(sale_price_real_2022, 1 - fraction, type = 7)
    high <- sale_price_real_2022 > cutoff
    .(tail_fraction = fraction, cutoff = cutoff, sales = .N, tail_sales = sum(high),
      actual_tail_fraction = mean(high), value_share = sum(sale_price_real_2022[high]) / sum(sale_price_real_2022),
      tail_contribution_to_mean = sum(sale_price_real_2022[high]) / .N,
      rest_contribution_to_mean = sum(sale_price_real_2022[!high]) / .N,
      tail_mean_price = mean(sale_price_real_2022[high]), rest_mean_price = mean(sale_price_real_2022[!high]),
      tail_apartment_share = mean(analysis_class[high] == 211), tail_mean_building_sqft = mean(res_char_bldg_sf[high]))
  }, by = .(treated, sale_year)]
}
tails <- rbindlist(tails)
check <- merge(tails, annual[, .(treated, sale_year, mean_price)], by = c("treated", "sale_year"))
stopifnot(max(abs(check$tail_contribution_to_mean + check$rest_contribution_to_mean - check$mean_price)) < 1e-7)
# Within-type means and group-specific pre-closure type shares separate the
# arithmetic role of houses versus apartment buildings from within-type prices.
composition <- sales[, .(sales = .N, mean_price = mean(sale_price_real_2022), median_price = median(sale_price_real_2022),
  mean_building_sqft = mean(res_char_bldg_sf), top5_sales = sum(top5),
  top5_sale_value = sum(sale_price_real_2022[top5])), by = .(treated, sale_year, property_type)]
composition[, sales_share := sales / sum(sales), by = .(treated, sale_year)]
composition[, top5_sales_share := top5_sales / sum(top5_sales), by = .(treated, sale_year)]
composition[, top5_value_share := top5_sale_value / sum(top5_sale_value), by = .(treated, sale_year)]
pre_shares <- sales[sale_year <= 2012, .(pre_sales = .N), by = .(treated, property_type)]
pre_shares[, pre_sales_share := pre_sales / sum(pre_sales), by = treated]
stopifnot(!anyDuplicated(pre_shares[, .(treated, property_type)]))
composition <- merge(composition, pre_shares, by = c("treated", "property_type"), all.x = TRUE)
stopifnot(!anyNA(composition), all(composition[, .N, by = .(treated, sale_year)]$N == 2L))
fixed_mix <- composition[, .(fixed_type_share_mean = sum(pre_sales_share * mean_price),
  reconstructed_mean = sum(sales_share * mean_price)), by = .(treated, sale_year)]
annual <- merge(annual, fixed_mix, by = c("treated", "sale_year"))
stopifnot(max(abs(annual$mean_price - annual$reconstructed_mean)) < 1e-7)
annual[, reconstructed_mean := NULL]
setorder(annual, treated, sale_year)
setorder(tails, tail_fraction, treated, sale_year)
setorder(composition, treated, sale_year, property_type)
expensive <- sales[top5 == TRUE]
setorder(expensive, treated, sale_year, -sale_price_real_2022, row_id)
expensive[, price_rank := frank(-sale_price_real_2022, ties.method = "min"), by = .(treated, sale_year)]
fwrite(annual, "../output/annual_prices.csv")
fwrite(tails, "../output/tail_contributions.csv")
fwrite(expensive, "../output/expensive_sales.csv")
fwrite(composition, "../output/property_composition.csv")
print(tails[tail_fraction == .05, .(treated, sale_year, tail_sales, value_share, tail_apartment_share)])
