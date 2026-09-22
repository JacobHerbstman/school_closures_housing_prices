# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sample_summary/code")
suppressPackageStartupMessages({library(data.table); library(arrow)})
source("../../../shared/code/report_data.R")

sales <- fread("../input/home_sales_2008_2018.csv",
               colClasses = list(character = c("row_id", "pin", "sale_document_num", "res_char_apts")))
exposure <- as.data.table(read_parquet("../input/exposure.parquet"))
exposure[, row_id := as.character(row_id)]
# One exposure row per master transaction; every clean sale must match once.
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(exposure$row_id), all(sales$row_id %in% exposure$row_id))
sales <- merge(sales, exposure, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyDuplicated(sales$row_id))
sales <- sales[has_school_distances == TRUE]

# A sale is treated (control) when a closed (stayed-open) site is within the
# radius and no site of the other group is. Sales within the radius of a
# welcoming school, another candidate, or a building vacated by a relocating
# welcoming school are excluded. Each sale is assigned to its nearest site.
samples <- rbindlist(lapply(c(0.25, 0.5), function(radius_miles) {
  radius_feet <- radius_miles * 5280
  near_treated <- sales$nearest_treated_site_distance_feet <= radius_feet
  near_control <- sales$nearest_control_site_distance_feet <= radius_feet
  keep <- xor(near_treated, near_control) &
    sales$nearest_welcoming_school_distance_feet > radius_feet &
    sales$nearest_other_candidate_site_distance_feet > radius_feet &
    sales$nearest_vacated_welcoming_building_distance_feet > radius_feet
  in_radius <- sales[keep]
  in_radius[, `:=`(
    radius = paste(radius_miles, "mile"),
    group = fifelse(nearest_treated_site_distance_feet <= radius_feet, "Closed", "Stayed open")
  )]
  in_radius[, school_site_id := fifelse(group == "Closed", nearest_treated_site_id, nearest_control_site_id)]
  rbindlist(list(
    copy(in_radius)[, property := "All property"],
    in_radius[analysis_class != 211L][, property := "Single-family"]
  ))
}))
samples[, `:=`(
  sample = paste0(property, ", ", radius),
  period = fcase(sale_year <= 2012L, "2008-2012", sale_year == 2013L, "2013", default = "2014-2018"),
  quarter = sale_year + (sale_quarter - 1L) / 4,
  unflagged = !reo_sale & !resale_within_365 & !price_outside_p01_p99 & !same_party_names
)]

summary_stats <- samples[, .(
  sales = .N,
  sites_with_sales = uniqueN(school_site_id),
  median_real_price = median(sale_price_real_2022),
  mean_real_price = mean(sale_price_real_2022),
  mean_building_sqft = mean(res_char_bldg_sf),
  mean_age = mean(sale_year - res_char_yrblt),
  share_two_to_six_units = mean(analysis_class == 211L),
  share_unknown_unit_count = mean(analysis_class == 211L & is.na(apartment_count)),
  share_reo = mean(reo_sale),
  share_resale_365 = mean(resale_within_365),
  share_price_tail = mean(price_outside_p01_p99),
  share_same_party = mean(same_party_names),
  share_unflagged = mean(unflagged),
  median_real_price_unflagged = median(sale_price_real_2022[unflagged]),
  share_month_only_date = mean(sale_date_precision == "sale_month")
), by = .(sample, group, period)]
setorder(summary_stats, sample, group, period)

# Annual and quarterly series for all clean sales and for unflagged sales.
stacked <- rbindlist(list(
  samples[, .(frequency = "annual", period_start = as.numeric(sale_year), sample, group,
              sale_price_real_2022, reo_sale, resale_within_365, unflagged)],
  samples[, .(frequency = "quarterly", period_start = quarter, sample, group,
              sale_price_real_2022, reo_sale, resale_within_365, unflagged)]
))
series <- rbindlist(list(
  stacked[, .(version = "All clean sales", sales = .N, median_real_price = median(sale_price_real_2022),
              mean_real_price = mean(sale_price_real_2022), share_reo = mean(reo_sale),
              share_resale_365 = mean(resale_within_365)),
          by = .(frequency, sample, group, period_start)],
  stacked[unflagged == TRUE, .(version = "Excluding flagged sales", sales = .N,
                               median_real_price = median(sale_price_real_2022),
                               mean_real_price = mean(sale_price_real_2022), share_reo = 0,
                               share_resale_365 = 0),
          by = .(frequency, sample, group, period_start)]
), use.names = TRUE)
setorder(series, frequency, version, sample, group, period_start)

# Site medians before and after, to show how much the group series mix
# different housing markets.
site_prices <- samples[period != "2013", .(sales = .N, median_real_price = median(sale_price_real_2022)),
                       by = .(sample, group, school_site_id, period)]
names <- fread("../input/schools.csv")[, .(school_names = paste(unique(trimws(school_name_sy1213)), collapse = " / ")),
                                       by = school_site_id]
stopifnot(!anyDuplicated(names$school_site_id), all(site_prices$school_site_id %in% names$school_site_id))
site_prices <- merge(site_prices, names, by = "school_site_id", all.x = TRUE)
setorder(site_prices, sample, group, school_site_id, period)

saveRDS(list(summary_stats = summary_stats, series = series, site_prices = site_prices),
        "../output/sample_summary.rds")
report <- capture.output({
  report_data(summary_stats, "summary_stats", c("sample", "group", "period"))
  report_data(series, "period_series", c("frequency", "version", "sample", "group", "period_start"))
  report_data(site_prices, "site_prices", c("sample", "school_site_id", "period"))
})
writeLines(trimws(report, which = "right"), "../report/sample_summary.txt")
print(summary_stats[, .(sample, group, period, sales, sites_with_sales, median_real_price = round(median_real_price),
                        share_reo = round(share_reo, 3), share_unflagged = round(share_unflagged, 3))])
