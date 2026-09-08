# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_rings/code")
# RStudio: set design <- "common" (or "varying"), then run below the argument block.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
design <- args[1]
stopifnot(design %in% c("varying", "common"))
suppressPackageStartupMessages({library(data.table); library(arrow); library(fixest)})
sales <- fread("../input/home_sales_2008_2018.csv", colClasses = c(row_id = "character"))
assignments <- if (design == "common") as.data.table(read_parquet("../output/common_ring_assignments.parquet")) else
  as.data.table(read_parquet("../output/ring_assignments.parquet"))
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(assignments[, .(ring, row_id)]),
          all(assignments$row_id %in% sales$row_id))
# Each ring-transaction assignment matches one cleaned transaction. Repetition
# across different specifications is intentional; no within-fit duplicates.
sales <- merge(assignments, sales, by = "row_id", all.x = TRUE, allow.cartesian = TRUE)
stopifnot(nrow(sales) == nrow(assignments))
sales[, `:=`(log_real_price = log(sale_price_real_2022), log_building_sqft = log(res_char_bldg_sf),
  log_land_sqft = log(res_char_land_sf), age_at_sale = sale_year - res_char_yrblt,
  apartments = fcoalesce(apartment_count, 0L), treated_post = treated * as.integer(sale_year >= 2014))]
controls <- paste("log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2) +",
  "age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments +",
  "factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)")
stopifnot(all(complete.cases(sales[, .(log_real_price, log_building_sqft, log_land_sqft, age_at_sale,
  res_char_beds, res_char_rooms, res_char_fbath, apartments, analysis_class, res_char_type_resd,
  res_char_cnst_qlty, res_char_repair_cnd)])))
coefficients <- list()
summaries <- list()
raw_trends <- list()
site_support <- list()
for (ring_name in unique(assignments$ring)) {
  sample <- copy(sales[ring == ring_name])
  stopifnot(!anyDuplicated(sample$row_id), identical(sort(unique(sample$sale_year)), 2008:2018))
  sample[, site_year_weight := 1 / .N, by = .(school_site_id, sale_year)]
  status <- unique(sample[, .(school_site_id, treated)])
  stopifnot(!anyDuplicated(status$school_site_id))
  cells <- sample[, .(sales = .N, mean_real_price = mean(sale_price_real_2022),
    mean_log_real_price = mean(log_real_price)), by = .(school_site_id, treated, sale_year)]
  roster <- merge(CJ(school_site_id = status$school_site_id, sale_year = 2008:2018), status, by = "school_site_id")
  roster <- merge(roster, cells, by = c("school_site_id", "treated", "sale_year"), all.x = TRUE)
  roster[is.na(sales), sales := 0L]
  roster[, ring := ring_name]
  site_support[[ring_name]] <- roster
  for (weighting_method in c("equal_transaction", "equal_site_year")) {
    cells[, weight := if (weighting_method == "equal_transaction") sales else 1]
    raw_trends[[paste(ring_name, weighting_method)]] <- cells[, .(
      mean_real_price = weighted.mean(mean_real_price, weight),
      mean_log_real_price = weighted.mean(mean_log_real_price, weight),
      sites = .N, sales = sum(sales)), by = .(treated, sale_year)][, `:=`(ring = ring_name, weighting = weighting_method)]
    sample[, analysis_weight := if (weighting_method == "equal_transaction") 1 else site_year_weight]
    for (specification in c("site_unadjusted", "site_hedonics", "group_hedonics")) {
      fixed_effects <- if (specification == "group_hedonics") "treated + sale_year" else "school_site_id + sale_year"
      covariates <- if (specification == "site_unadjusted") "" else paste("+", controls)
      for (outcome in c("dollars", "log")) {
        dependent <- if (outcome == "dollars") "sale_price_real_2022" else "log_real_price"
        for (estimator in c("did", "event")) {
          data <- if (estimator == "did") sample[sale_year != 2013] else sample
          treatment_term <- if (estimator == "did") "treated_post" else "i(sale_year, treated, ref = 2012)"
          formula <- as.formula(paste(dependent, "~", treatment_term, covariates, "|", fixed_effects))
          # Keep singleton-site observations explicit. They supply no within-site
          # treatment contrast in site-FE fits, rather than being silently dropped.
          fit <- feols(formula, data = data, weights = ~analysis_weight, vcov = ~school_site_id,
                       fixef.rm = "none", notes = FALSE)
          stopifnot(nobs(fit) == nrow(data))
          estimates <- as.data.table(coeftable(fit), keep.rownames = "term")
          setnames(estimates, c("term", "estimate", "std_error", "t_statistic", "p_value"))
          intervals <- confint(fit)
          estimates[, `:=`(conf_low = intervals[, 1], conf_high = intervals[, 2])]
          estimates <- estimates[term == "treated_post" | grepl("^sale_year::[0-9]+:treated$", term)]
          stopifnot(nrow(estimates) == if (estimator == "did") 1L else 10L)
          estimates[, `:=`(ring = ring_name, weighting = weighting_method, specification = specification,
            outcome = outcome, estimator = estimator,
            sale_year = if (estimator == "event") as.integer(sub("sale_year::([0-9]+):treated", "\\1", term)) else NA_integer_)]
          coefficients[[length(coefficients) + 1L]] <- estimates
          pretest <- if (estimator == "event") wald(fit, keep = "^sale_year::(2008|2009|2010|2011):treated$", print = FALSE) else NULL
          nclusters <- uniqueN(data$school_site_id)
          summaries[[length(summaries) + 1L]] <- data.table(ring = ring_name, weighting = weighting_method,
            specification = specification, outcome = outcome, estimator = estimator,
            observations = nobs(fit), treated_sites = uniqueN(data[treated == 1, school_site_id]),
            control_sites = uniqueN(data[treated == 0, school_site_id]),
            pretrend_f = if (estimator == "event") pretest$stat else NA_real_,
            pretrend_p = if (estimator == "event") pf(pretest$stat, pretest$df1, nclusters - 1, lower.tail = FALSE) else NA_real_,
            pretrend_df1 = if (estimator == "event") pretest$df1 else NA_integer_,
            pretrend_df2 = if (estimator == "event") nclusters - 1L else NA_integer_,
            collinear_terms = paste(fit$collin.var, collapse = "; "), fixest_version = as.character(packageVersion("fixest")))
        }
      }
    }
  }
}
coefficients <- rbindlist(coefficients)
summaries <- rbindlist(summaries)
raw_trends <- rbindlist(raw_trends)
site_support <- rbindlist(site_support)
stopifnot(nrow(summaries) == 120L, nrow(coefficients) == 660L,
  !anyDuplicated(coefficients[, .(ring, weighting, specification, outcome, estimator, term)]),
  all(is.finite(coefficients$estimate)), all(is.finite(coefficients$std_error)), all(coefficients$std_error > 0))
if (design == "common") {
  stopifnot(uniqueN(summaries$treated_sites) == 1L, uniqueN(summaries$control_sites) == 1L)
  fwrite(coefficients, "../output/common_coefficients.csv")
  fwrite(summaries, "../output/common_model_summary.csv")
  fwrite(raw_trends, "../output/common_raw_trends.csv")
  fwrite(site_support, "../output/common_site_year_support.csv")
} else {
  fwrite(coefficients, "../output/coefficients.csv")
  fwrite(summaries, "../output/model_summary.csv")
  fwrite(raw_trends, "../output/raw_trends.csv")
  fwrite(site_support, "../output/site_year_support.csv")
}
print(coefficients[estimator == "did" & weighting == "equal_site_year" & specification == "site_hedonics",
  .(ring, outcome, estimate, conf_low, conf_high)])
