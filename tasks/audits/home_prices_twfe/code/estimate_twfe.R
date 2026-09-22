# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
suppressPackageStartupMessages({library(data.table); library(arrow); library(fixest)})
source("../../../shared/code/report_data.R")
setFixest_nthreads(1)

sales <- fread("../input/home_sales_2008_2018.csv",
               colClasses = list(character = c("row_id", "pin", "sale_document_num", "res_char_apts")))
exposure <- as.data.table(read_parquet("../input/home_school_exposure_2006_2025.parquet"))
exposure[, row_id := as.character(row_id)]
# One exposure row per master transaction; every clean sale must match once.
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(exposure$row_id), all(sales$row_id %in% exposure$row_id))
sales <- merge(sales, exposure, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(!anyDuplicated(sales$row_id))
sales <- sales[has_school_distances == TRUE]

# A sale is treated (control) when a closed (stayed-open) site is within the
# radius and no site of the other group is. Sales within the radius of a
# welcoming school, another February candidate, or a building vacated by a
# relocating welcoming school are excluded. Each sale uses its nearest site of
# its group for the site fixed effect and the standard-error cluster.
# A quarter mile (1,320 feet) balances proximity and support.
samples <- rbindlist(lapply(0.25, function(radius_miles) {
  radius_feet <- radius_miles * 5280
  near_treated <- sales$nearest_treated_site_distance_feet <= radius_feet
  near_control <- sales$nearest_control_site_distance_feet <= radius_feet
  in_radius <- sales[xor(near_treated, near_control) &
                       sales$nearest_welcoming_school_distance_feet > radius_feet &
                       sales$nearest_other_candidate_site_distance_feet > radius_feet &
                       sales$nearest_vacated_welcoming_building_distance_feet > radius_feet]
  in_radius[, `:=`(radius = paste(radius_miles, "mile"),
                   treated = as.integer(nearest_treated_site_distance_feet <= radius_feet))]
  rbindlist(list(copy(in_radius)[, property := "All property"],
                 in_radius[analysis_class != 211L][, property := "Single-family"]))
}))
samples[, `:=`(
  sample = property,
  school_site_id = fifelse(treated == 1L, nearest_treated_site_id, nearest_control_site_id),
  log_price = log(sale_price_real_2022),
  log_building_sqft = log(res_char_bldg_sf),
  log_land_sqft = log(res_char_land_sf),
  age_at_sale = sale_year - res_char_yrblt,
  two_to_six_units = as.integer(analysis_class == 211L),
  treated_post = treated * as.integer(sale_year >= 2014L)
)]
stopifnot(all(is.finite(samples$log_price)), all(samples$age_at_sale >= 0),
          !anyNA(samples$school_site_id), setequal(unique(samples$sale_year), 2008:2018))

# Every property-class dummy is omitted: classes 205/207 and 210/295 switch at
# age 62, which the age terms already capture. REO resales and resales within
# 365 days stay in the sample, with indicators.
hedonics <- paste(
  "log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +",
  "age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath +",
  "i(res_char_type_resd) + i(res_char_cnst_qlty) + i(res_char_repair_cnd) + reo_sale + resale_within_365")
# A unit-count factor with an unknown level changed no estimate by more than
# 0.003 log points (September 22), so the 2-6-unit indicator stands in for it.
control_sets <- c(
  "Site and year effects" = "",
  "Hedonics" = paste("+", hedonics, "+ two_to_six_units")
)
# Robustness to the flagged sales: each variant removes one kind of flagged sale.
samples[, `:=`(
  keep_all = TRUE,
  keep_no_reo = !reo_sale,
  keep_no_quick_resale = !resale_within_365,
  keep_no_price_tail = !price_outside_p01_p99,
  keep_unflagged = !reo_sale & !resale_within_365 & !price_outside_p01_p99 & !same_party_names
)]
variants <- c(
  "All clean sales" = "keep_all",
  "Drop REO resales" = "keep_no_reo",
  "Drop resales within 365 days" = "keep_no_quick_resale",
  "Drop 1st-99th price tails" = "keep_no_price_tail",
  "Drop all flagged sales" = "keep_unflagged"
)
designs <- c(event = "i(sale_year, treated, ref = 2012)", did = "treated_post")

# Site-year weights give each school site equal total weight in every year.
samples[, site_year_weight := 1 / .N, by = .(sample, school_site_id, sale_year)]

# Baseline price tiers: each study site's 2008-2012 median real price among all
# clean sales within a quarter mile, split at the median of site medians across
# both groups. Tiers are fixed before 2013 and apply to both property samples.
site_tiers <- samples[sample == "All property" & sale_year <= 2012L,
                      .(pre_median_real_price = median(sale_price_real_2022), pre_sales = .N),
                      by = .(school_site_id, treated)]
tier_cutoff <- median(site_tiers$pre_median_real_price)
site_tiers[, price_tier := fifelse(pre_median_real_price <= tier_cutoff, "Lower-price sites", "Higher-price sites")]
stopifnot(!anyDuplicated(site_tiers$school_site_id), all(samples$school_site_id %in% site_tiers$school_site_id))
samples[site_tiers, on = "school_site_id", price_tier := i.price_tier]
print(site_tiers[, .(sites = .N, median_of_site_medians = round(median(pre_median_real_price))), by = .(price_tier, treated)])

# Log real price; site-clustered errors. The pooled difference-in-differences
# compares 2014-2018 with 2008-2012. Used by the main grid and the
# leave-one-site-out estimates.
fit_model <- function(data, control_name, design, weighting) {
  if (design == "did") data <- data[sale_year != 2013L]
  feols(as.formula(paste("log_price ~", designs[[design]], control_sets[[control_name]], "| school_site_id + sale_year")),
        data = data, vcov = ~school_site_id, weights = if (weighting == "Site-years") ~site_year_weight else NULL)
}
# Event coefficients relative to 2012 and, as a linear combination with its
# full covariance, relative to the 2008-2012 average (2012 contributes zero).
event_years <- setdiff(2008:2018, 2012)
event_terms <- paste0("sale_year::", event_years, ":treated")
pre_average <- as.numeric(event_years %in% 2008:2011) / 5
contrast <- t(sapply(2008:2018, function(year) as.numeric(event_years == year) - pre_average))
event_table <- function(fit) {
  stopifnot(all(event_terms %in% names(coef(fit))))
  b <- coef(fit)[event_terms]
  V <- vcov(fit)[event_terms, event_terms]
  rbind(data.table(normalization = "2012", sale_year = event_years, estimate = unname(b), std_error = sqrt(diag(V))),
        data.table(normalization = "2008-2012 average", sale_year = 2008:2018, estimate = as.vector(contrast %*% b),
                   std_error = sqrt(pmax(diag(contrast %*% V %*% t(contrast)), 0))))
}

# One row per model. Site-year weighting is estimated on all clean sales only;
# the baseline price tiers on all clean sales and without REO resales.
specifications <- CJ(sample = unique(samples$sample), tier = c("All sites", "Lower-price sites", "Higher-price sites"),
                     variant = names(variants), controls = names(control_sets), design = names(designs),
                     weighting = c("Transactions", "Site-years"), sorted = FALSE)
specifications <- specifications[(weighting == "Transactions" | variant == "All clean sales") &
  (tier == "All sites" | (weighting == "Transactions" & variant %in% c("All clean sales", "Drop REO resales")))]
events <- list()
did <- list()
models <- list()
for (k in seq_len(nrow(specifications))) {
  spec <- specifications[k]
  data <- samples[sample == spec$sample & get(variants[[spec$variant]]) == TRUE &
                    (spec$tier == "All sites" | price_tier == spec$tier)]
  fit <- fit_model(data, spec$controls, spec$design, spec$weighting)
  if (spec$design == "event") events[[k]] <- cbind(spec, event_table(fit)) else
    did[[k]] <- cbind(spec, data.table(estimate = coef(fit)[["treated_post"]], std_error = se(fit)[["treated_post"]]))
  # Joint test that the 2008-2011 event coefficients are zero (relative to 2012).
  pre_test <- if (spec$design == "event") wald(fit, keep = "sale_year::20(08|09|10|11):treated", print = FALSE) else NULL
  models[[k]] <- cbind(spec, data.table(
    observations = nobs(fit), treated_sites = uniqueN(data[treated == 1L, school_site_id]),
    control_sites = uniqueN(data[treated == 0L, school_site_id]),
    pre_trend_p_value = if (is.null(pre_test)) NA_real_ else pre_test$p,
    dropped_terms = paste(fit$collin.var, collapse = "; ")))
}
events <- rbindlist(events)[, design := NULL]
did <- rbindlist(did)[, design := NULL]
models <- rbindlist(models)
stopifnot(all(is.finite(events$estimate)), all(is.finite(did$estimate)), all(did$std_error > 0),
          !anyDuplicated(events[, .(sample, tier, variant, controls, weighting, normalization, sale_year)]),
          !anyDuplicated(did[, .(sample, tier, variant, controls, weighting)]), nrow(models) == nrow(specifications))
events[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]
did[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]

# Leave one closed site out: all clean sales, transaction weights, event study.
leave_one_out <- list()
for (sample_name in unique(samples$sample)) {
  data <- samples[sample == sample_name]
  for (control_name in names(control_sets)) {
    for (site in sort(unique(data[treated == 1L, school_site_id]))) {
      fit <- fit_model(data[school_site_id != site], control_name, "event", "Transactions")
      leave_one_out[[length(leave_one_out) + 1L]] <- event_table(fit)[
        , `:=`(sample = sample_name, controls = control_name, dropped_site = site,
               dropped_site_sales = data[school_site_id == site, .N])]
    }
  }
}
leave_one_out <- rbindlist(leave_one_out)
site_names <- fread("../input/schools.csv")[, .(site_name = paste(unique(trimws(school_name_sy1213)), collapse = " / ")),
                                            by = school_site_id]
stopifnot(!anyDuplicated(site_names$school_site_id), all(leave_one_out$dropped_site %in% site_names$school_site_id))
leave_one_out <- merge(leave_one_out, site_names, by.x = "dropped_site", by.y = "school_site_id", all.x = TRUE)
leave_one_out[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]

support <- samples[, .(sales = .N, sites = uniqueN(school_site_id), reo = sum(reo_sale),
                       resale_365 = sum(resale_within_365), price_tail = sum(price_outside_p01_p99)),
                   by = .(sample, treated, sale_year)]
setorder(events, sample, tier, variant, controls, weighting, normalization, sale_year)
setorder(did, sample, tier, variant, controls, weighting)
setorder(site_tiers, school_site_id)
setorder(leave_one_out, sample, controls, dropped_site, normalization, sale_year)
setorder(support, sample, treated, sale_year)
saveRDS(list(events = events, did = did, models = models, leave_one_out = leave_one_out, support = support,
             site_tiers = site_tiers),
        "../output/twfe.rds")
report <- capture.output({
  report_data(events, "events", c("sample", "tier", "variant", "controls", "weighting", "normalization", "sale_year"))
  report_data(did, "did", c("sample", "tier", "variant", "controls", "weighting"))
  report_data(models, "models", c("sample", "tier", "variant", "controls", "design", "weighting"))
  report_data(site_tiers, "site_tiers", "school_site_id")
  report_data(leave_one_out, "leave_one_out", c("sample", "controls", "dropped_site", "normalization", "sale_year"))
  report_data(support, "support", c("sample", "treated", "sale_year"))
})
writeLines(trimws(report, which = "right"), "../report/twfe.txt")
print(did[, .(sample, tier, variant, controls, weighting, estimate = round(estimate, 3),
              ci_low = round(ci_low, 3), ci_high = round(ci_high, 3))])
