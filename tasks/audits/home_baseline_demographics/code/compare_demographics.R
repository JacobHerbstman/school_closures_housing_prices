# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_baseline_demographics/code")
library(data.table)
demographics <- fread("../output/baseline_demographics.csv", colClasses = c(geoid = "character"))
homes <- fread("../output/home_census_geographies.csv",
               colClasses = c(row_id = "character", tract_geoid = "character", block_group_geoid = "character"))
stopifnot(!anyDuplicated(demographics$geoid), !anyDuplicated(homes$row_id))
variables <- c("median_household_income", "poverty_pct", "college_pct", "black_pct", "white_pct",
               "hispanic_pct", "unemployment_pct", "renter_pct", "vacancy_pct", "population_per_sq_mile")
labels <- c("Median household income (2012 dollars)", "Below poverty threshold (%)", "Bachelor's degree or more, age 25+ (%)",
            "Non-Hispanic Black (%)", "Non-Hispanic White (%)", "Hispanic, any race (%)", "Unemployed, civilian labor force (%)",
            "Renter-occupied, occupied units (%)", "Vacant, all housing units (%)", "Population per square mile of land")
# Resample schools within treatment status, retaining each school's sales.
# Use the same draws across characteristics, geographies, and weighting schemes.
set.seed(20260904)
control_sites <- sort(unique(homes[treated == 0 & sale_year <= 2012, school_site_id]))
treated_sites <- sort(unique(homes[treated == 1 & sale_year <= 2012, school_site_id]))
stopifnot(length(control_sites) == 48L, length(treated_sites) == 29L)
control_resamples <- replicate(1999L, tabulate(sample.int(48L, 48L, replace = TRUE), nbins = 48L))
treated_resamples <- replicate(1999L, tabulate(sample.int(29L, 29L, replace = TRUE), nbins = 29L))
results <- list()
for (geography_level in c("tract", "block_group")) {
  pre <- copy(homes[sale_year <= 2012])
  pre[, geoid := get(paste0(geography_level, "_geoid"))]
  # Many sales to one ACS geography, matched by home location. No averaging
  # of tract medians is described as a pooled household median.
  joined <- merge(pre, demographics[geography == geography_level], by = "geoid", all.x = TRUE)
  stopifnot(nrow(joined) == nrow(pre), !anyNA(joined$geography))
  for (variable in variables) {
    sample <- joined[, .(treated, school_site_id, geoid, value = get(variable))]
    for (weighting_method in c("equal_transaction", "equal_site")) {
      if (weighting_method == "equal_transaction") units <- sample[, .(treated, value)]
      if (weighting_method == "equal_site") units <- sample[, .(
        value = if (all(is.na(value))) NA_real_ else mean(value, na.rm = TRUE)), by = .(treated, school_site_id)]
      means <- units[, .(mean = mean(value, na.rm = TRUE), variance = var(value, na.rm = TRUE), n = sum(!is.na(value))), by = treated]
      setorder(means, treated)
      stopifnot(identical(means$treated, 0:1), all(means$n > 1))
      # Site-level sufficient statistics reproduce transaction means/variances
      # without expanding repeated bootstrap copies of every sale.
      moments <- if (weighting_method == "equal_transaction") {
        sample[, .(n = sum(!is.na(value)), total = sum(value, na.rm = TRUE),
                   total_sq = sum(value^2, na.rm = TRUE)), by = .(treated, school_site_id)]
      } else {
        units[, .(n = as.integer(!is.na(value)), total = fifelse(is.na(value), 0, value),
                  total_sq = fifelse(is.na(value), 0, value^2)), by = .(treated, school_site_id)]
      }
      control_moments <- moments[treated == 0][match(control_sites, school_site_id), .(n, total, total_sq)]
      treated_moments <- moments[treated == 1][match(treated_sites, school_site_id), .(n, total, total_sq)]
      control_draws <- t(control_resamples) %*% as.matrix(control_moments)
      treated_draws <- t(treated_resamples) %*% as.matrix(treated_moments)
      control_variance <- (control_draws[, 3] - control_draws[, 2]^2 / control_draws[, 1]) / (control_draws[, 1] - 1)
      treated_variance <- (treated_draws[, 3] - treated_draws[, 2]^2 / treated_draws[, 1]) / (treated_draws[, 1] - 1)
      bootstrap_difference <- (treated_draws[, 2] / treated_draws[, 1] - control_draws[, 2] / control_draws[, 1]) /
        sqrt((control_variance + treated_variance) / 2)
      stopifnot(all(is.finite(bootstrap_difference)))
      interval <- quantile(bootstrap_difference, c(0.025, 0.975), names = FALSE)
      results[[length(results) + 1L]] <- data.table(geography = geography_level,
        weighting = weighting_method, variable, label = labels[match(variable, variables)],
        control_mean = means$mean[1], treated_mean = means$mean[2],
        difference = means$mean[2] - means$mean[1],
        standardized_difference = (means$mean[2] - means$mean[1]) / sqrt(mean(means$variance)),
        ci_lower = interval[1], ci_upper = interval[2], bootstrap_repetitions = 1999L,
        control_units = means$n[1], treated_units = means$n[2],
        control_missing_sales = sample[treated == 0, sum(is.na(value))],
        treated_missing_sales = sample[treated == 1, sum(is.na(value))],
        control_geographies = uniqueN(sample[treated == 0 & !is.na(value), geoid]),
        treated_geographies = uniqueN(sample[treated == 1 & !is.na(value), geoid]))
    }
  }
  income_reliability <- unique(joined[, .(geoid, B19013_001E, B19013_001M, income_censored)])
  cat(geography_level, ": unique pre-sale geographies =", nrow(income_reliability),
      "; median income 90% MOE =", median(income_reliability$B19013_001M, na.rm = TRUE),
      "; income missing =", sum(is.na(income_reliability$B19013_001E)),
      "; income censored =", sum(income_reliability$income_censored), "\n")
}
balance <- rbindlist(results)
stopifnot(!anyDuplicated(balance[, .(geography, weighting, variable)]), nrow(balance) == 40L)
fwrite(balance, "../output/demographic_balance.csv")
print(balance[geography == "tract" & weighting == "equal_transaction",
              .(variable, treated_mean, control_mean, standardized_difference, treated_missing_sales, control_missing_sales)])

png("../output/demographic_balance.png", width = 2000, height = 1250, res = 170)
par(mfrow = c(1, 2), mar = c(5, 12, 4, 1), oma = c(4, 0, 2, 0), las = 1)
axis_limit <- ceiling(max(abs(c(balance$ci_lower, balance$ci_upper))) * 10) / 10 + 0.05
for (geography_level in c("tract", "block_group")) {
  plot(NA, xlim = c(-axis_limit, axis_limit), ylim = c(0.5, 10.5), yaxt = "n",
       xlab = "Treated minus control (standard deviations)", ylab = "",
       main = if (geography_level == "tract") "Census tracts" else "Block groups")
  axis(2, at = 10:1, labels = c("Median household income", "Poverty", "College graduates", "Non-Hispanic Black",
       "Non-Hispanic White", "Hispanic", "Unemployment", "Renting", "Vacancy", "Population density"), tick = FALSE, cex.axis = 0.8)
  abline(v = 0, col = "gray50")
  for (weighting_method in c("equal_transaction", "equal_site")) {
    rows <- balance[geography == geography_level & weighting == weighting_method]
    # Match the fixed economic ordering, independent of CSV ordering.
    rows <- rows[match(variables, variable)]
    positions <- 10:1 + if (weighting_method == "equal_transaction") 0.1 else -0.1
    segments(rows$ci_lower, positions, rows$ci_upper, positions,
             col = if (weighting_method == "equal_transaction") "#145c9e" else "#b34b2e")
    points(rows$standardized_difference, positions,
           pch = if (weighting_method == "equal_transaction") 16 else 1,
           col = if (weighting_method == "equal_transaction") "#145c9e" else "#b34b2e", cex = 1.1)
  }
}
mtext("Pre-closure neighborhood balance: unchanged 30/49 school split", outer = TRUE, side = 3, cex = 1.2)
mtext("ACS 2008–2012; eligible sales in 2008–2012. Filled blue: equal sales; open orange: equal sites.",
      outer = TRUE, side = 1, line = 1, cex = 0.8)
mtext("Bars: 95% percentile intervals from 1,999 school-site bootstrap draws; ACS survey uncertainty excluded.",
      outer = TRUE, side = 1, line = 2.2, cex = 0.75)
dev.off()
