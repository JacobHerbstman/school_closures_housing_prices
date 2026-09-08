# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(fixest)
})

sales <- fread("../input/home_sales_2008_2018.csv",
               select = c("row_id", "pin", "sale_year", "sale_month", "sale_price_real_2022",
                          "res_char_bldg_sf", "res_char_land_sf", "res_char_yrblt",
                          "res_char_beds", "res_char_rooms", "res_char_fbath",
                          "apartment_count", "analysis_class", "res_char_type_resd",
                          "res_char_cnst_qlty", "res_char_repair_cnd"),
               colClasses = list(character = c("row_id", "pin")))
connection <- dbConnect(duckdb(), dbdir = ":memory:")
exposure <- as.data.table(dbGetQuery(connection, "
  SELECT CAST(row_id AS VARCHAR) AS row_id, focal_exposure_025,
         nearest_treated_site_id, nearest_control_site_id,
         n_welcoming_schools_025, n_other_candidate_sites_025
  FROM read_parquet('../input/home_school_exposure_2006_2025.parquet')
"))
dbDisconnect(connection, shutdown = TRUE)

# One transaction to one exposure record; every clean sale must match exactly.
stopifnot(nrow(sales) > 0L, !anyDuplicated(sales$row_id),
          !anyDuplicated(exposure$row_id), all(sales$row_id %in% exposure$row_id))
rows_before <- nrow(sales)
sales <- merge(sales, exposure, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(nrow(sales) == rows_before, !anyNA(sales$focal_exposure_025))

# Keep sales within a quarter mile of exactly one treatment group, excluding
# proximity to welcoming schools and candidates outside the 30/49 comparison.
# Homes near multiple schools of the same status enter once.
sales <- sales[focal_exposure_025 %in% c("treated_only", "control_only") &
                 n_welcoming_schools_025 == 0L & n_other_candidate_sites_025 == 0L]
sales[, `:=`(
  treated = as.integer(focal_exposure_025 == "treated_only"),
  school_site_id = fifelse(focal_exposure_025 == "treated_only",
                          nearest_treated_site_id, nearest_control_site_id),
  log_real_price = log(sale_price_real_2022)
)]
stopifnot(nrow(sales) > 0L, !anyNA(sales$school_site_id),
          all(is.finite(sales$log_real_price)),
          identical(sort(unique(sales$sale_year)), 2008:2018))
# One transaction to one amenity row. Missing distances must not change the
# quarter-mile sample when controls are added.
amenities <- fread("../input/home_amenity_distances.csv", colClasses = c(row_id = "character"))
stopifnot(!anyDuplicated(amenities$row_id), all(sales$row_id %in% amenities$row_id))
rows_before <- nrow(sales)
sales <- merge(sales, amenities, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(nrow(sales) == rows_before,
          all(is.finite(as.matrix(sales[, .(lake_miles, park_miles, cta_miles)]))))
print(sales[, .(sales = .N, mean_lake_miles = mean(lake_miles),
  mean_park_miles = mean(park_miles), mean_cta_miles = mean(cta_miles)), by = treated])

site_status <- unique(sales[, .(school_site_id, treated)])
stopifnot(!anyDuplicated(site_status$school_site_id),
          uniqueN(site_status[treated == 1L, school_site_id]) > 1L,
          uniqueN(site_status[treated == 0L, school_site_id]) > 1L)
# The upstream price sample already requires complete core characteristics.
# Zero apartments means not applicable outside class 211, with property class
# included separately. No additional complete-case restriction is imposed here.
stopifnot(all(sales$res_char_bldg_sf > 0), all(sales$res_char_land_sf > 0),
          all(sales$res_char_yrblt <= sales$sale_year),
          !anyNA(sales[analysis_class == 211L, apartment_count]))
sales[, `:=`(log_building_sqft = log(res_char_bldg_sf),
             log_land_sqft = log(res_char_land_sf),
             age_at_sale = sale_year - res_char_yrblt,
             apartments = fcoalesce(apartment_count, 0L))]
stopifnot(all(complete.cases(sales[, .(log_building_sqft, log_land_sqft,
  age_at_sale, res_char_beds, res_char_rooms, res_char_fbath, apartments,
  analysis_class, res_char_type_resd, res_char_cnst_qlty, res_char_repair_cnd)])))

# Calendar half-years: January-June is year, July-December is year + 0.5.
stopifnot(!anyNA(sales$sale_month), all(sales$sale_month %in% 1:12))
sales[, sale_halfyear := sale_year + 0.5 * (sale_month > 6L)]
stopifnot(identical(sort(unique(sales$sale_halfyear)), seq(2008, 2018.5, 0.5)),
          nrow(unique(sales[, .(treated, sale_halfyear)])) == 44L)

# Every observed site-period gets total weight one; no price is imputed for
# a site-period without a sale. We retain all transactions in the same sample.
sales[, site_year_weight := 1 / .N, by = .(school_site_id, sale_year)]
sales[, site_halfyear_weight := 1 / .N, by = .(school_site_id, sale_halfyear)]
stopifnot(all(abs(sales[, sum(site_year_weight), by = .(school_site_id, sale_year)]$V1 - 1) < 1e-12),
          all(abs(sales[, sum(site_halfyear_weight), by = .(school_site_id, sale_halfyear)]$V1 - 1) < 1e-12))

site_support <- sales[, .(pre = sum(sale_year <= 2012L), post = sum(sale_year >= 2014L)),
                      by = school_site_id]
stopifnot(all(site_support$pre > 0L), all(site_support$post > 0L))

support <- sales[, .(sales = .N, parcels = uniqueN(pin),
                     mean_real_price = mean(sale_price_real_2022),
                     mean_log_real_price = mean(log_real_price)),
                 by = .(school_site_id, treated, sale_year)]
setorder(support, school_site_id, sale_year)
fwrite(support, "../output/site_year_support.csv")

# Annual timing: show 2013 as a transition-year event coefficient. The pooled
# DiD excludes that year and compares 2008-2012 with full post years 2014-2018.
# Each transaction has equal weight. These are prices conditional on sale.
did_sales <- sales[sale_year != 2013L]
did_sales[, treated_post := treated * as.integer(sale_year >= 2014L)]
models <- list(
  did_log = feols(log_real_price ~ treated_post | school_site_id + sale_year,
                  data = did_sales, vcov = ~school_site_id),
  did_dollars = feols(sale_price_real_2022 ~ treated_post | school_site_id + sale_year,
                      data = did_sales, vcov = ~school_site_id),
  event_log = feols(log_real_price ~ i(sale_year, treated, ref = 2012) | school_site_id + sale_year,
                    data = sales, vcov = ~school_site_id),
  event_dollars = feols(sale_price_real_2022 ~ i(sale_year, treated, ref = 2012) | school_site_id + sale_year,
                        data = sales, vcov = ~school_site_id),
  did_hedonic_log = feols(log_real_price ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_year,
    data = did_sales, vcov = ~school_site_id),
  did_hedonic_dollars = feols(sale_price_real_2022 ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_year,
    data = did_sales, vcov = ~school_site_id),
  event_hedonic_log = feols(log_real_price ~ i(sale_year, treated, ref = 2012) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_year,
    data = sales, vcov = ~school_site_id),
  event_hedonic_dollars = feols(sale_price_real_2022 ~ i(sale_year, treated, ref = 2012) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_year,
    data = sales, vcov = ~school_site_id),
  event_semiannual_log = feols(log_real_price ~ i(sale_halfyear, treated, ref = 2012.5) |
    school_site_id + sale_halfyear, data = sales, vcov = ~school_site_id),
  event_semiannual_dollars = feols(sale_price_real_2022 ~ i(sale_halfyear, treated, ref = 2012.5) |
    school_site_id + sale_halfyear, data = sales, vcov = ~school_site_id),
  event_semiannual_hedonic_log = feols(log_real_price ~ i(sale_halfyear, treated, ref = 2012.5) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_halfyear,
    data = sales, vcov = ~school_site_id),
  event_semiannual_hedonic_dollars = feols(sale_price_real_2022 ~ i(sale_halfyear, treated, ref = 2012.5) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_halfyear,
    data = sales, vcov = ~school_site_id),
  did_semiannual_hedonic_log = feols(log_real_price ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_halfyear,
    data = did_sales, vcov = ~school_site_id),
  did_semiannual_hedonic_dollars = feols(sale_price_real_2022 ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) | school_site_id + sale_halfyear,
    data = did_sales, vcov = ~school_site_id),
  did_semiannual_amenity_log = feols(log_real_price ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) +
    i(sale_halfyear, lake_miles) + i(sale_halfyear, park_miles) + i(sale_halfyear, cta_miles) | school_site_id + sale_halfyear,
    data = did_sales, vcov = ~school_site_id),
  did_semiannual_amenity_dollars = feols(sale_price_real_2022 ~ treated_post +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) +
    i(sale_halfyear, lake_miles) + i(sale_halfyear, park_miles) + i(sale_halfyear, cta_miles) | school_site_id + sale_halfyear,
    data = did_sales, vcov = ~school_site_id),
  event_semiannual_amenity_log = feols(log_real_price ~ i(sale_halfyear, treated, ref = 2012.5) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) +
    i(sale_halfyear, lake_miles) + i(sale_halfyear, park_miles) + i(sale_halfyear, cta_miles) | school_site_id + sale_halfyear,
    data = sales, vcov = ~school_site_id),
  event_semiannual_amenity_dollars = feols(sale_price_real_2022 ~ i(sale_halfyear, treated, ref = 2012.5) +
    log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) +
    i(sale_halfyear, lake_miles) + i(sale_halfyear, park_miles) + i(sale_halfyear, cta_miles) | school_site_id + sale_halfyear,
    data = sales, vcov = ~school_site_id)
)

# The same substantive specifications, estimated with inverse site-period
# transaction counts. Calendar frequency determines which count is relevant.
transaction_models <- names(models)
for (model_name in transaction_models) {
  model_sales <- if (startsWith(model_name, "event_")) sales else did_sales
  site_model_name <- sub("^(did|event)_", "\\1_site_", model_name)
  models[[site_model_name]] <- update(models[[model_name]], data = model_sales,
    weights = if (grepl("_semiannual_", model_name)) ~site_halfyear_weight else ~site_year_weight)
}

raw_trends <- list()
period_support <- list()
for (frequency_name in c("annual", "semiannual")) {
  sales[, period := if (frequency_name == "annual") sale_year else sale_halfyear]
  cells <- sales[, .(sales = .N, parcels = uniqueN(pin),
    mean_real_price = mean(sale_price_real_2022), mean_log_real_price = mean(log_real_price)),
    by = .(school_site_id, treated, period)]
  # Full site-period roster makes empty periods explicit in the support output.
  roster <- merge(CJ(school_site_id = site_status$school_site_id, period = sort(unique(sales$period))),
                  site_status, by = "school_site_id")
  roster <- merge(roster, cells, by = c("school_site_id", "treated", "period"), all.x = TRUE)
  roster[is.na(sales), `:=`(sales = 0L, parcels = 0L)]
  roster[, frequency := frequency_name]
  period_support[[frequency_name]] <- roster
  for (weighting_method in c("equal_transaction", "equal_site_period")) {
    cells[, weight := if (weighting_method == "equal_transaction") sales else 1]
    raw_trends[[paste(frequency_name, weighting_method)]] <- cells[, .(
      mean_real_price = weighted.mean(mean_real_price, weight),
      mean_log_real_price = weighted.mean(mean_log_real_price, weight),
      contributing_sites = .N, sales = sum(sales), min_sales_per_site = min(sales),
      median_sales_per_site = median(sales)), by = .(treated, period)][
        , `:=`(frequency = frequency_name, weighting = weighting_method)]
  }
}
raw_trends <- rbindlist(raw_trends)
period_support <- rbindlist(period_support)
setorder(raw_trends, frequency, weighting, treated, period)
setorder(period_support, frequency, school_site_id, period)
fwrite(raw_trends, "../output/raw_price_trends.csv")
fwrite(period_support, "../output/site_period_support.csv")
print(period_support[, .(site_periods = .N, empty = sum(sales == 0L),
  single_sale = sum(sales == 1L)), by = .(frequency, treated)])

coefficients <- list()
summaries <- list()
for (model_name in names(models)) {
  model <- models[[model_name]]
  is_event <- startsWith(model_name, "event_")
  is_semiannual <- grepl("_semiannual_", model_name)
  model_sales <- if (is_event) sales else did_sales
  stopifnot(nobs(model) == nrow(model_sales))
  estimates <- as.data.table(coeftable(model), keep.rownames = "term")
  setnames(estimates, c("term", "estimate", "std_error", "t_statistic", "p_value"))
  intervals <- confint(model, level = 0.95)
  stopifnot(identical(estimates$term, rownames(intervals)))
  estimates[, `:=`(conf_low = intervals[, 1], conf_high = intervals[, 2])]
  # Export the treatment coefficients; controls are estimated in the same model.
  estimates <- estimates[term == "treated_post" | grepl("^sale_(year|halfyear)::[0-9.]+:treated$", term)]
  stopifnot(nrow(estimates) == if (!is_event) 1L else if (is_semiannual) 21L else 10L)
  estimates[, `:=`(model = model_name,
    sale_year = if (is_event) as.integer(sub("sale_(year|halfyear)::([0-9.]+):treated", "\\2", term)) else NA_integer_,
    sale_halfyear = if (is_event && is_semiannual) as.numeric(sub("sale_halfyear::([0-9.]+):treated", "\\1", term)) else NA_real_)]
  coefficients[[model_name]] <- estimates
  pretest <- if (is_event) wald(model, keep = if (is_semiannual)
    "^sale_halfyear::(2008|2009|2010|2011)([.]5)?:treated$|^sale_halfyear::2012:treated$" else
    "^sale_year::(2008|2009|2010|2011):treated$", print = FALSE) else NULL
  if (is_event) {
    # wald() uses residual observation degrees of freedom by default; use the
    # number of independent site clusters minus one for this joint F test.
    pretest$df2 <- uniqueN(model_sales$school_site_id) - 1L
    pretest$p <- pf(pretest$stat, pretest$df1, pretest$df2, lower.tail = FALSE)
    stopifnot(pretest$df1 == if (is_semiannual) 9L else 4L)
  }
  summaries[[model_name]] <- data.table(
    model = model_name, outcome = if (endsWith(model_name, "log")) "log_real_price" else "real_price_2022_dollars",
    weighting = if (grepl("_site_", model_name)) "equal_site_period" else "equal_transaction",
    empty_site_periods = period_support[frequency == if (is_semiannual) "semiannual" else "annual"][
      if (is_event) rep(TRUE, .N) else floor(period) != 2013, sum(sales == 0L)],
    frequency = if (is_semiannual) "semiannual" else "annual",
    hedonics = grepl("_(hedonic|amenity)_", model_name),
    amenity_by_halfyear = grepl("_amenity_", model_name),
    dropped_collinear_terms = paste(model$collin.var, collapse = "; "),
    observations = nobs(model), school_sites = uniqueN(model_sales$school_site_id),
    treated_sites = uniqueN(model_sales[treated == 1L, school_site_id]),
    control_sites = uniqueN(model_sales[treated == 0L, school_site_id]),
    reference_year = if (is_event) 2012L else NA_integer_,
    reference_halfyear = if (is_event && is_semiannual) 2012.5 else NA_real_,
    includes_transition_year = is_event,
    pretrend_f = if (is_event) pretest$stat else NA_real_,
    pretrend_p = if (is_event) pretest$p else NA_real_,
    pretrend_df1 = if (is_event) pretest$df1 else NA_integer_,
    pretrend_df2 = if (is_event) pretest$df2 else NA_integer_,
    fixest_version = as.character(packageVersion("fixest"))
  )
}
coefficients <- rbindlist(coefficients)
summaries <- rbindlist(summaries)
stopifnot(nrow(coefficients) == 348L, all(is.finite(coefficients$estimate)),
          all(is.finite(coefficients$std_error)), all(coefficients$std_error > 0))
fwrite(coefficients, "../output/coefficients.csv")
fwrite(summaries, "../output/model_summary.csv")
print(coefficients[startsWith(model, "did_")])
print(summaries)
