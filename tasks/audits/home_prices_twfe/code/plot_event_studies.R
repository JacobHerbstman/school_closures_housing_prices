# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")

suppressPackageStartupMessages(library(data.table))
coefficients <- fread("../output/coefficients.csv")
summaries <- fread("../output/model_summary.csv")
stopifnot(!anyDuplicated(coefficients[, .(model, term)]), !anyDuplicated(summaries$model))

for (plot_frequency in c("annual", "semiannual", "amenities")) {
  is_semiannual <- plot_frequency != "annual"
  is_amenity_comparison <- plot_frequency == "amenities"
  reference <- if (is_semiannual) 2012.5 else 2012
  periods <- if (is_semiannual) seq(2008, 2018.5, 0.5) else 2008:2018
  model_names <- if (is_amenity_comparison)
    c("event_semiannual_hedonic_log", "event_semiannual_hedonic_dollars",
      "event_semiannual_amenity_log", "event_semiannual_amenity_dollars") else if (is_semiannual)
    c("event_semiannual_log", "event_semiannual_dollars",
      "event_semiannual_hedonic_log", "event_semiannual_hedonic_dollars") else
    c("event_log", "event_dollars", "event_hedonic_log", "event_hedonic_dollars")
  if (is_amenity_comparison) {
    png("../output/event_studies_amenities.png", width = 2400, height = 2000, res = 200)
  } else if (is_semiannual) {
    png("../output/event_studies_semiannual.png", width = 2400, height = 2000, res = 200)
  } else {
    png("../output/event_studies.png", width = 2200, height = 1900, res = 200)
  }
  par(mfrow = c(2, 2), mar = c(if (is_semiannual) 6 else 5, 5, 3.5, 1), oma = c(5, 0, 3, 0))
  for (model_name in model_names) {
    is_log <- endsWith(model_name, "log")
    has_hedonics <- grepl("_(hedonic|amenity)_", model_name)
    has_amenities <- grepl("_amenity_", model_name)
    estimates <- coefficients[model == model_name]
    estimates[, period := if (is_semiannual) sale_halfyear else sale_year]
    model_summary <- summaries[model == model_name]
    stopifnot(nrow(estimates) == length(periods) - 1L, nrow(model_summary) == 1L,
              setequal(estimates$period, setdiff(periods, reference)))
    scale <- if (is_log) 1 else 1000
    plot_values <- rbind(estimates[, .(period, estimate, conf_low, conf_high)],
                    data.table(period = reference, estimate = 0, conf_low = 0, conf_high = 0))
    setorder(plot_values, period)
    # Hold the vertical scale fixed across controls within each outcome/frequency.
    comparison <- coefficients[model %in% model_names & endsWith(model, if (is_log) "log" else "dollars")]
    limits <- range(c(0, comparison$conf_low, comparison$conf_high)) / scale
    plot(plot_values$period, plot_values$estimate / scale, type = "n", ylim = limits,
         xaxt = "n", xlab = "",
         ylab = if (is_log) "Effect on log real sale price" else "Effect on real sale price ($1,000s, 2022 dollars)",
         main = paste(if (is_log) "Log prices" else "Dollar prices",
                      if (has_amenities) "| Hedonics + amenities" else if (has_hedonics) "| With hedonics" else "| No hedonics"))
    rect(if (is_semiannual) 2012.75 else 2012.5, par("usr")[3],
         if (is_semiannual) 2013.75 else 2013.5, par("usr")[4], col = "grey94", border = NA)
    abline(h = 0, col = "grey55", lty = 2)
    axis(1, at = periods, labels = if (is_semiannual)
      paste(floor(periods), ifelse(periods %% 1 == 0, "H1", "H2")) else periods,
      las = 2, cex.axis = if (is_semiannual) .72 else 1)
    mtext(if (is_semiannual) "Sale half-year" else "Sale year", side = 1,
          line = if (is_semiannual) 4.5 else 3.5)
    lines(plot_values$period, plot_values$estimate / scale, col = "#176B87", lwd = 1.5)
    arrows(estimates$period, estimates$conf_low / scale,
           estimates$period, estimates$conf_high / scale,
           angle = 90, code = 3, length = .03, col = "#176B87", lwd = 1.3)
    points(plot_values$period, plot_values$estimate / scale,
           pch = ifelse(plot_values$period == reference, 1, 16), col = "#176B87", cex = 1)
    mtext(sprintf("Joint pre-period test (%s): p = %.3f",
                  if (is_semiannual) "2008 H1-2012 H1" else "2008-2011", model_summary$pretrend_p),
          side = 3, line = .4, cex = .8)
  }
  mtext(if (is_amenity_comparison) "Chicago school closures | amenities interacted with half-year" else
          paste("Chicago school closures |", plot_frequency, "event studies"),
        side = 3, outer = TRUE, line = 1, font = 2, cex = 1.2)
  mtext(if (is_amenity_comparison) "Same transactions, hedonics, school-site and sale-half-year fixed effects throughout." else
        paste("Same transactions and school-site fixed effects throughout;",
              if (is_semiannual) "sale-half-year" else "sale-year", "fixed effects. No amenity controls."),
        side = 1, outer = TRUE, line = 1.4, cex = .8)
  mtext(paste(if (is_semiannual) "2012 H2" else "2012",
              "is the reference; shaded 2013 is the transition year. Pointwise 95% CIs cluster by school site."),
        side = 1, outer = TRUE, line = 2.7, cex = .8)
  mtext("Quarter-mile treated/control sample; excludes welcoming/other-candidate exposure. Annual top-0.1% PPSF trim; equal transaction weights.",
        side = 1, outer = TRUE, line = 4, cex = .72)
  dev.off()
}
