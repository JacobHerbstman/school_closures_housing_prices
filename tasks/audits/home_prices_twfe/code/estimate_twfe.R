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
samples <- rbindlist(lapply(c(0.25, 0.5), function(radius_miles) {
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
  sample = paste0(property, ", ", radius),
  school_site_id = fifelse(treated == 1L, nearest_treated_site_id, nearest_control_site_id),
  log_price = log(sale_price_real_2022),
  log_building_sqft = log(res_char_bldg_sf),
  log_land_sqft = log(res_char_land_sf),
  age_at_sale = sale_year - res_char_yrblt,
  two_to_six_units = as.integer(analysis_class == 211L),
  # Unit count of a 2-6-unit building, with an explicit unknown level; houses
  # and townhouses are their own level.
  unit_count = fcase(analysis_class != 211L, "house or townhouse",
                     is.na(apartment_count), "unknown",
                     default = paste(apartment_count, "units")),
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
control_sets <- c(
  "Site and year effects" = "",
  "Hedonics" = paste("+", hedonics, "+ two_to_six_units"),
  "Hedonics and unit count" = paste("+", hedonics, "+ i(unit_count, ref = 'house or townhouse')")
)
designs <- c(event = "i(sale_year, treated, ref = 2012)", did = "treated_post")

# Log real price; each transaction has equal weight; site-clustered errors.
# The pooled difference-in-differences compares 2014-2018 with 2008-2012.
coefficients <- list()
models <- list()
for (sample_name in unique(samples$sample)) {
  for (control_name in names(control_sets)) {
    for (design in names(designs)) {
      data <- if (design == "did") samples[sample == sample_name & sale_year != 2013L] else samples[sample == sample_name]
      fit <- feols(as.formula(paste("log_price ~", designs[[design]], control_sets[[control_name]],
                                    "| school_site_id + sale_year")),
                   data = data, vcov = ~school_site_id)
      estimates <- as.data.table(coeftable(fit), keep.rownames = "term")[
        grepl("^treated_post$|^sale_year::", term)]
      setnames(estimates, c("term", "estimate", "std_error", "t_value", "p_value"))
      estimates[, `:=`(sample = sample_name, controls = control_name, design = design, sale_year = NA_integer_)]
      estimates[grepl("^sale_year::", term), sale_year := as.integer(sub("sale_year::([0-9]+):treated", "\\1", term))]
      # Joint test that the 2008-2011 event coefficients are zero.
      pre_test <- if (design == "event") wald(fit, keep = "sale_year::20(08|09|10|11):treated", print = FALSE) else NULL
      coefficients[[length(coefficients) + 1L]] <- estimates
      models[[length(models) + 1L]] <- data.table(
        sample = sample_name, controls = control_name, design = design, observations = nobs(fit),
        treated_sites = uniqueN(data[treated == 1L, school_site_id]),
        control_sites = uniqueN(data[treated == 0L, school_site_id]),
        pre_trend_p_value = if (is.null(pre_test)) NA_real_ else pre_test$p,
        dropped_terms = paste(fit$collin.var, collapse = "; "))
    }
  }
}
coefficients <- rbindlist(coefficients)
models <- rbindlist(models)
stopifnot(all(is.finite(coefficients$estimate)), all(coefficients$std_error > 0),
          !anyDuplicated(coefficients[, .(sample, controls, design, term)]),
          nrow(models) == uniqueN(samples$sample) * length(control_sets) * length(designs))
coefficients[, `:=`(ci_low = estimate - 1.96 * std_error, ci_high = estimate + 1.96 * std_error)]

support <- samples[, .(sales = .N, sites = uniqueN(school_site_id),
                       unknown_unit_count = sum(unit_count == "unknown")),
                   by = .(sample, treated, sale_year)]
setorder(coefficients, sample, controls, design, sale_year)
setorder(support, sample, treated, sale_year)
saveRDS(list(coefficients = coefficients, models = models, support = support), "../output/twfe.rds")
report <- capture.output({
  report_data(coefficients, "coefficients", c("sample", "controls", "design", "term"))
  report_data(models, "models", c("sample", "controls", "design"))
  report_data(support, "support", c("sample", "treated", "sale_year"))
})
writeLines(trimws(report, which = "right"), "../report/twfe.txt")
print(models)
print(coefficients[design == "did", .(sample, controls, estimate = round(estimate, 3),
                                      ci_low = round(ci_low, 3), ci_high = round(ci_high, 3))])
