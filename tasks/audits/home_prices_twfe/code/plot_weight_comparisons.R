# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
library(data.table)
raw <- fread("../output/raw_price_trends.csv")
coefficients <- fread("../output/coefficients.csv")
summaries <- fread("../output/model_summary.csv")
stopifnot(!anyDuplicated(raw[, .(frequency, weighting, treated, period)]),
          !anyDuplicated(coefficients[, .(model, term)]), !anyDuplicated(summaries$model))

for (frequency_name in c("annual", "semiannual")) {
  periods <- if (frequency_name == "annual") 2008:2018 else seq(2008, 2018.5, .5)
  png(sprintf("../output/raw_prices_%s.png", frequency_name), width = 2300, height = 1700, res = 190)
  par(mfrow = c(2, 2), mar = c(5.5, 5, 3, 1), oma = c(4, 0, 3, 0), las = 1)
  for (weighting_method in c("equal_transaction", "equal_site_period")) {
    for (outcome_name in c("dollars", "logs")) {
      rows <- raw[frequency == frequency_name & weighting == weighting_method]
      scale <- if (outcome_name == "dollars") 1000 else 1
      rows[, value := if (outcome_name == "dollars") mean_real_price / scale else mean_log_real_price]
      limits <- raw[frequency == frequency_name, if (outcome_name == "dollars") range(mean_real_price) / 1000 else range(mean_log_real_price)]
      plot(NA, xlim = range(periods), ylim = limits, xaxt = "n", xlab = "", ylab = if (outcome_name == "dollars")
        "Mean sale price ($1,000s, 2022 dollars)" else "Mean log real sale price",
        main = paste(if (weighting_method == "equal_transaction") "Equal transactions" else "Equal observed sites per period",
                     if (outcome_name == "dollars") "| Dollars" else "| Logs"))
      rect(if (frequency_name == "annual") 2012.5 else 2012.75, par("usr")[3],
           if (frequency_name == "annual") 2013.5 else 2013.75, par("usr")[4], col = "gray94", border = NA)
      axis(1, at = periods, labels = if (frequency_name == "annual") periods else
        paste(floor(periods), ifelse(periods %% 1 == 0, "H1", "H2")), las = 2,
        cex.axis = if (frequency_name == "annual") .85 else .62)
      for (status in c(0L, 1L)) {
        group <- rows[treated == status][order(period)]
        lines(group$period, group$value, type = "o", pch = if (status == 1L) 17 else 16,
              col = if (status == 1L) "#b54d2f" else "#176b87", lwd = 1.5, cex = .75)
      }
      legend("topleft", c("Treated", "Control"), col = c("#b54d2f", "#176b87"), pch = c(17, 16), lty = 1, bty = "n", cex = .8)
    }
  }
  mtext(paste("Raw", frequency_name, "price trends | same 30/49 school split"), side = 3, outer = TRUE, line = 1, font = 2, cex = 1.15)
  mtext("Descriptive means of the same clean sales; no fixed effects or controls. Logs are means of log prices, not logs of mean prices.",
        side = 1, outer = TRUE, line = 1, cex = .78)
  mtext("Equal sites: average within site-period, then across sites with sales. Empty periods remain missing; 2013 is shaded.",
        side = 1, outer = TRUE, line = 2.3, cex = .78)
  dev.off()
}

for (comparison_name in c("annual", "semiannual", "amenities")) {
  is_semiannual <- comparison_name != "annual"
  periods <- if (is_semiannual) seq(2008, 2018.5, .5) else 2008:2018
  reference <- if (is_semiannual) 2012.5 else 2012
  base_models <- if (comparison_name == "annual") c("event_dollars", "event_log", "event_hedonic_dollars", "event_hedonic_log") else
    if (comparison_name == "semiannual") c("event_semiannual_dollars", "event_semiannual_log", "event_semiannual_hedonic_dollars", "event_semiannual_hedonic_log") else
      c("event_semiannual_amenity_dollars", "event_semiannual_amenity_log")
  png(sprintf("../output/event_studies_weights_%s.png", comparison_name), width = 2400,
      height = if (comparison_name == "amenities") 1100 else 2000, res = 190)
  par(mfrow = c(if (comparison_name == "amenities") 1 else 2, 2),
      mar = c(if (is_semiannual) 6 else 5, 5, 4.5, 1), oma = c(4.5, 0, 3, 0))
  all_models <- c(base_models, sub("^event_", "event_site_", base_models))
  for (base_model in base_models) {
    is_log <- endsWith(base_model, "log")
    scale <- if (is_log) 1 else 1000
    values <- coefficients[model %in% all_models & endsWith(model, if (is_log) "log" else "dollars")]
    limits <- range(c(0, values$conf_low, values$conf_high)) / scale
    plot(NA, xlim = range(periods) + c(-.15, .15), ylim = limits, xaxt = "n", xlab = "",
      ylab = if (is_log) "Effect on log real sale price" else "Effect on real sale price ($1,000s, 2022 dollars)",
      main = paste(if (is_log) "Logs" else "Dollars", if (grepl("amenity", base_model)) "| Hedonics + amenities" else
                     if (grepl("hedonic", base_model)) "| With hedonics" else "| No controls"))
    rect(if (is_semiannual) 2012.75 else 2012.5, par("usr")[3], if (is_semiannual) 2013.75 else 2013.5,
         par("usr")[4], col = "gray94", border = NA)
    abline(h = 0, col = "gray50", lty = 2)
    axis(1, at = periods, labels = if (is_semiannual) paste(floor(periods), ifelse(periods %% 1 == 0, "H1", "H2")) else periods,
         las = 2, cex.axis = if (is_semiannual) .7 else .9)
    for (weighting_method in c("equal_transaction", "equal_site_period")) {
      model_name <- if (weighting_method == "equal_transaction") base_model else sub("^event_", "event_site_", base_model)
      rows <- coefficients[model == model_name]
      rows[, period := if (is_semiannual) sale_halfyear else sale_year]
      stopifnot(setequal(rows$period, setdiff(periods, reference)))
      color <- if (weighting_method == "equal_transaction") "#176b87" else "#b54d2f"
      offset <- (if (is_semiannual) .035 else .07) * if (weighting_method == "equal_transaction") -1 else 1
      values <- rbind(rows[, .(period, estimate, conf_low, conf_high)], data.table(period = reference, estimate = 0, conf_low = 0, conf_high = 0))
      setorder(values, period)
      lines(values$period + offset, values$estimate / scale, col = color, lwd = 1.2)
      arrows(rows$period + offset, rows$conf_low / scale, rows$period + offset, rows$conf_high / scale,
             code = 3, angle = 90, length = .025, col = color)
      points(values$period + offset, values$estimate / scale, pch = if (weighting_method == "equal_transaction") 16 else 17,
             col = color, cex = .8)
    }
    tests <- summaries[match(c(base_model, sub("^event_", "event_site_", base_model)), model), pretrend_p]
    mtext(sprintf("Joint pre-period p: equal transactions %.3f; equal sites %.3f", tests[1], tests[2]), side = 3, line = .4, cex = .77)
  }
  mtext(paste("Equal transaction versus equal site-period weights |", comparison_name, "event studies"),
        side = 3, outer = TRUE, line = 1, font = 2, cex = 1.15)
  mtext("Blue circles: equal transactions. Orange triangles: equal observed sites per period (each sale weighted by 1/site-period sales).",
        side = 1, outer = TRUE, line = 1, cex = .77)
  mtext(paste("Same sample and specification within each panel; school-site and calendar-period fixed effects.",
              if (is_semiannual) "2012 H2" else "2012", "reference; 2013 shaded."), side = 1, outer = TRUE, line = 2.2, cex = .77)
  mtext("Pointwise 95% intervals cluster by school site. Empty site-periods remain missing. No demographic controls added.",
        side = 1, outer = TRUE, line = 3.4, cex = .77)
  dev.off()
}
