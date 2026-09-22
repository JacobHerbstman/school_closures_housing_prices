# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sales_volume/code")
suppressPackageStartupMessages({library(data.table); library(arrow); library(fixest)})
source("../../../shared/code/report_data.R")
setFixest_nthreads(1)

master <- fread("../input/corrected_home_sale_characteristics_2006_2025.csv",
                select = c("row_id", "sale_year", "sale_price_nominal", "sale_type", "property_class",
                           "sale_filter_same_sale_within_365", "sale_filter_less_than_10k", "sale_filter_deed_type"),
                colClasses = list(character = "row_id"))
clean <- fread("../input/home_sales_2008_2018.csv", select = c("row_id", "analysis_class", "reo_sale"),
               colClasses = list(character = "row_id"))
exposure <- as.data.table(read_parquet("../input/home_school_exposure_2006_2025.parquet"))
exposure[, row_id := as.character(row_id)]
# One exposure row per master transaction; the clean sample is a subset of the master.
stopifnot(!anyDuplicated(master$row_id), !anyDuplicated(clean$row_id), !anyDuplicated(exposure$row_id),
          setequal(master$row_id, exposure$row_id), all(clean$row_id %in% master$row_id))
master <- master[sale_year %between% c(2008L, 2018L)]
master <- merge(master, exposure, by = "row_id", all.x = TRUE, sort = FALSE)
master <- merge(master, clean, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyDuplicated(master$row_id))
master <- master[has_school_distances == TRUE]

# Same quarter-mile comparison as the price models: treated (control) when a
# closed (stayed-open) site is within 1,320 feet and no site of the other group
# is, excluding sales near welcoming schools, other candidates, and vacated
# welcoming buildings. Each sale counts once, at its nearest site of its group.
radius_feet <- 1320
master <- master[xor(nearest_treated_site_distance_feet <= radius_feet, nearest_control_site_distance_feet <= radius_feet) &
                   nearest_welcoming_school_distance_feet > radius_feet &
                   nearest_other_candidate_site_distance_feet > radius_feet &
                   nearest_vacated_welcoming_building_distance_feet > radius_feet]
master[, `:=`(treated = as.integer(nearest_treated_site_distance_feet <= radius_feet))]
master[, school_site_id := fifelse(treated == 1L, nearest_treated_site_id, nearest_control_site_id)]

# Sales measures. Market sales are every master transaction (single-parcel,
# non-condo residential) passing the county flags as a non-land sale above
# $10,000, including foreclosure auctions; single-family uses the sale-record
# class because multi-building records have no analysis class. The clean
# measures count the price sample, with REO resales separately.
single_family_classes <- c(202:210, 234, 278, 295)
master[, `:=`(
  market_sale = !sale_filter_same_sale_within_365 & !sale_filter_less_than_10k & !sale_filter_deed_type &
    sale_price_nominal > 10000 & !is.na(sale_type) & sale_type != "LAND",
  in_clean = !is.na(reo_sale)
)]
counts <- rbindlist(lapply(c("All property", "Single-family"), function(property) {
  sales <- if (property == "All property") master else
    master[fifelse(in_clean, analysis_class %in% single_family_classes, property_class %in% single_family_classes)]
  rbindlist(list(
    sales[market_sale == TRUE, .(sales = .N), by = .(school_site_id, sale_year)][, measure := "All market sales"],
    sales[in_clean == TRUE, .(sales = .N), by = .(school_site_id, sale_year)][, measure := "Clean price-sample sales"],
    sales[in_clean == TRUE & reo_sale == FALSE, .(sales = .N), by = .(school_site_id, sale_year)][, measure := "Clean sales excluding REO"],
    sales[in_clean == TRUE & reo_sale == TRUE, .(sales = .N), by = .(school_site_id, sale_year)][, measure := "REO resales"]
  ))[, property := property]
}))

# Balanced site-year panel: a study site with no sale in a year is a zero. The
# 78 study sites come from the school roster, not from observed sales.
sites <- fread("../input/schools.csv")[housing_treat_30 == 1L | housing_control_49 == 1L,
                                       .(treated = as.integer(max(housing_treat_30)),
                                         site_name = paste(unique(trimws(school_name_sy1213)), collapse = " / ")),
                                       by = school_site_id]
stopifnot(!anyDuplicated(sites$school_site_id), all(counts$school_site_id %in% sites$school_site_id))
panel <- CJ(property = unique(counts$property), measure = unique(counts$measure),
            school_site_id = sites$school_site_id, sale_year = 2008:2018)
panel <- merge(panel, counts, by = c("property", "measure", "school_site_id", "sale_year"), all.x = TRUE)
panel[is.na(sales), sales := 0L]
panel <- merge(panel, sites[, .(school_site_id, treated)], by = "school_site_id")
panel[, treated_post := treated * as.integer(sale_year >= 2014L)]
# Baseline price tiers come from the price analysis (2008-2012 site median real
# price, split at the median of site medians). A site with no clean sale in
# 2008-2012 has no tier and enters only the all-sites models.
site_tiers <- readRDS("../input/twfe.rds")$site_tiers
stopifnot(!anyDuplicated(site_tiers$school_site_id), all(site_tiers$school_site_id %in% sites$school_site_id))
panel[site_tiers, on = "school_site_id", price_tier := i.price_tier]
stopifnot(nrow(panel) == uniqueN(counts$property) * uniqueN(counts$measure) * nrow(sites) * 11L)

# Poisson pseudo-likelihood with site and year effects, clustered by site.
# Sites with no sales in any year carry no information and are dropped.
# Coefficients are log changes in expected sales; 2012 is the reference year.
events <- list()
did <- list()
for (property_name in unique(panel$property)) {
 for (tier_name in c("All sites", "Lower-price sites", "Higher-price sites")) {
  for (measure_name in unique(panel$measure)) {
    data <- panel[property == property_name & measure == measure_name &
                    (tier_name == "All sites" | price_tier %in% tier_name)]
    event_fit <- fepois(sales ~ i(sale_year, treated, ref = 2012) | school_site_id + sale_year,
                        data = data, vcov = ~school_site_id)
    did_fit <- fepois(sales ~ treated_post | school_site_id + sale_year,
                      data = data[sale_year != 2013L], vcov = ~school_site_id)
    event_terms <- as.data.table(coeftable(event_fit), keep.rownames = "term")[grepl("^sale_year::", term)]
    setnames(event_terms, c("term", "estimate", "std_error", "z_value", "p_value"))
    pre_test <- wald(event_fit, keep = "sale_year::20(08|09|10|11):treated", print = FALSE)
    events[[length(events) + 1L]] <- event_terms[, `:=`(
      property = property_name, tier = tier_name, measure = measure_name,
      sale_year = as.integer(sub("sale_year::([0-9]+):treated", "\\1", term)))]
    did[[length(did) + 1L]] <- data.table(
      property = property_name, tier = tier_name, measure = measure_name, estimate = coef(did_fit)[["treated_post"]],
      std_error = se(did_fit)[["treated_post"]], pre_trend_p_value = pre_test$p,
      sites_used = data[, sum(sales), by = school_site_id][V1 > 0, .N],
      pre_sales_treated = data[treated == 1L & sale_year <= 2012L, sum(sales)],
      pre_sales_control = data[treated == 0L & sale_year <= 2012L, sum(sales)])
  }
 }
}
events <- rbindlist(events)
did <- rbindlist(did)
events[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]
did[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]
stopifnot(all(is.finite(events$estimate)), all(is.finite(did$estimate)))

annual <- rbind(
  panel[, .(tier = "All sites", mean_sales_per_site = mean(sales), total_sales = sum(sales)), by = .(property, measure, treated, sale_year)],
  panel[!is.na(price_tier), .(mean_sales_per_site = mean(sales), total_sales = sum(sales)),
        by = .(property, measure, tier = price_tier, treated, sale_year)], use.names = TRUE)
setorder(events, property, tier, measure, sale_year)
setorder(did, property, tier, measure)
setorder(annual, property, tier, measure, treated, sale_year)
setorder(panel, property, measure, school_site_id, sale_year)
saveRDS(list(panel = panel, annual = annual, events = events, did = did), "../output/volume.rds")
report <- capture.output({
  report_data(panel, "panel", c("property", "measure", "school_site_id", "sale_year"))
  report_data(events, "events", c("property", "tier", "measure", "sale_year"))
  report_data(did, "did", c("property", "tier", "measure"))
})
writeLines(trimws(report, which = "right"), "../report/volume.txt")
print(did[, .(property, tier, measure, estimate = round(estimate, 3), ci_low = round(ci_low, 3), ci_high = round(ci_high, 3),
              pre_p = round(pre_trend_p_value, 3), pre_sales_treated, pre_sales_control)])
