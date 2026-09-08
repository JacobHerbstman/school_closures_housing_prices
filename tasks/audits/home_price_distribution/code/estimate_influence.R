# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
suppressPackageStartupMessages({library(data.table); library(fixest)})
sales <- fread("../output/analysis_sample.csv", colClasses = c(row_id = "character", pin = "character"))
baseline <- fread("../input/baseline_coefficients.csv")
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(baseline[, .(model, term)]))
sales[, treated_post := treated * as.integer(sale_year >= 2014)]
roster <- unique(sales[, .(school_site_id, treated, school_names)])
stopifnot(!anyDuplicated(roster$school_site_id))
# Use the baseline annual specifications, equal transaction weights, and the
# retained school sites for clustering. Omission changes no other membership rule.
coefficients <- list()
summaries <- list()
index <- 0L
for (omitted in c(0L, sort(roster$school_site_id))) {
  retained <- sales[school_site_id != omitted]
  for (design in c("did", "event")) {
    model_sales <- retained[if (design == "did") sale_year != 2013 else rep(TRUE, .N)]
    for (hedonic in c(FALSE, TRUE)) {
      for (outcome in c("log", "dollars")) {
        index <- index + 1L
        model_name <- paste0(design, if (hedonic) "_hedonic" else "", "_", outcome)
        formula_text <- paste0(if (outcome == "log") "log_real_price" else "sale_price_real_2022", " ~ ",
          if (design == "did") "treated_post" else "i(sale_year, treated, ref = 2012)",
          if (hedonic) paste0(" + log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2)",
            " + age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments",
            " + factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)") else "",
          " | school_site_id + sale_year")
        fit <- feols(as.formula(formula_text), data = model_sales, vcov = ~school_site_id, nthreads = 1, notes = FALSE)
        stopifnot(nobs(fit) == nrow(model_sales))
        estimates <- as.data.table(coeftable(fit), keep.rownames = "term")
        setnames(estimates, c("term", "estimate", "std_error", "t_statistic", "p_value"))
        intervals <- confint(fit)
        estimates[, `:=`(conf_low = intervals[,1], conf_high = intervals[,2])]
        estimates <- estimates[term == "treated_post" | grepl("^sale_year::[0-9]+:treated$", term)]
        stopifnot(nrow(estimates) == if (design == "did") 1L else 10L)
        estimates[, `:=`(model = model_name, omitted_site_id = omitted,
          sale_year = if (design == "event") as.integer(sub("sale_year::([0-9]+):treated", "\\1", term)) else NA_integer_)]
        reference <- baseline[model == model_name, .(term, baseline_estimate = estimate, baseline_se = std_error)]
        estimates <- merge(estimates, reference, by = "term", all.x = TRUE)
        stopifnot(!anyNA(estimates$baseline_estimate))
        if (omitted == 0) stopifnot(max(abs(estimates$estimate - estimates$baseline_estimate)) < 1e-6,
          max(abs(estimates$std_error - estimates$baseline_se)) < 1e-6)
        estimates[, change_from_full := estimate - baseline_estimate]
        coefficients[[index]] <- estimates
        pre <- if (design == "event") wald(fit, keep = "^sale_year::(2008|2009|2010|2011):treated$", print = FALSE) else NULL
        summaries[[index]] <- data.table(model = model_name, omitted_site_id = omitted,
          omitted_school = if (omitted == 0) "Full sample" else roster[school_site_id == omitted, school_names],
          omitted_treated = if (omitted == 0) NA_integer_ else roster[school_site_id == omitted, treated],
          removed_sales = sum(sales$school_site_id == omitted), observations = nobs(fit),
          treated_sites = uniqueN(model_sales[treated == 1, school_site_id]), control_sites = uniqueN(model_sales[treated == 0, school_site_id]),
          pretrend_p = if (design == "event") pf(pre$stat, pre$df1, uniqueN(model_sales$school_site_id)-1, lower.tail = FALSE) else NA_real_)
      }
    }
  }
  message("Completed full sample / omitted site: ", omitted)
}
coefficients <- rbindlist(coefficients)
summaries <- rbindlist(summaries)
stopifnot(nrow(summaries) == 78L*8L, nrow(coefficients) == 78L*44L,
  !anyDuplicated(coefficients[, .(model, omitted_site_id, term)]), all(is.finite(coefficients$estimate)))
setorder(coefficients, model, omitted_site_id, term)
setorder(summaries, model, omitted_site_id)
fwrite(coefficients, "../output/site_omission_coefficients.csv")
fwrite(summaries, "../output/site_omission_models.csv")
print(coefficients[omitted_site_id != 0 & startsWith(model, "did"),
  .(full = baseline_estimate[1], minimum = min(estimate), maximum = max(estimate)), by = model])
