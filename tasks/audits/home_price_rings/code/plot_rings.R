# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_rings/code")
# RStudio: set design <- "common" (or "varying"), then run below the argument block.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
design <- args[1]
stopifnot(design %in% c("varying", "common"))
library(data.table)
if (design == "common") {
  raw <- fread("../output/common_raw_trends.csv")
  coefficients <- fread("../output/common_coefficients.csv")
  summaries <- fread("../output/common_model_summary.csv")
} else {
  raw <- fread("../output/raw_trends.csv")
  coefficients <- fread("../output/coefficients.csv")
  summaries <- fread("../output/model_summary.csv")
}
rings <- c("within_0125", "annulus_0125_025", "annulus_025_05", "within_025", "within_05")
labels <- c("0–⅛ mile", "⅛–¼ mile", "¼–½ mile", "0–¼ mile", "0–½ mile")
if (design == "common") {
  stopifnot(uniqueN(summaries$treated_sites) == 1L, uniqueN(summaries$control_sites) == 1L)
  roster_label <- sprintf("%d treated / %d control sites", summaries$treated_sites[1], summaries$control_sites[1])
}
colors <- c("#176b87", "#b54d2f")
for (weighting_method in c("equal_transaction", "equal_site_year")) {
  png(paste0(if (design == "common") "../output/common_raw_" else "../output/raw_", weighting_method, ".png"), width = 2400, height = 2500, res = 220)
  par(mfrow = c(3, 2), mar = c(3.5, 4.2, 3.6, 1), oma = c(3, 0, 4, 0))
  for (index in 1:3) {
    for (outcome_name in c("dollars", "log")) {
      data <- copy(raw[ring == rings[index] & weighting == weighting_method])
      data[, value := if (outcome_name == "dollars") mean_real_price / 1000 else mean_log_real_price]
      limits <- range(data$value)
      padding <- max(diff(limits) * .12, .02)
      plot(NA, xlim = c(2008, 2018), ylim = limits + c(-padding, padding), xaxt = "n",
        xlab = "", ylab = if (outcome_name == "dollars") "Mean price (2022 $ thousands)" else "Mean log real price",
        main = labels[index])
      axis(1, at = seq(2008, 2018, 2))
      rect(2012.5, par("usr")[3], 2013.5, par("usr")[4], col = "#eeeeee", border = NA)
      for (status in 0:1) {
        series <- data[treated == status][order(sale_year)]
        lines(series$sale_year, series$value, type = "b", pch = if (status == 0) 16 else 17,
              col = colors[status + 1], lwd = 1.5)
      }
      counts <- data[, .(sites = max(sites), sales = sum(sales)), by = treated][order(treated)]
      mtext(sprintf("Sales: %s treated / %s control", format(counts[treated == 1, sales], big.mark = ","),
        format(counts[treated == 0, sales], big.mark = ",")), side = 3, line = .4, cex = .72)
      if (index == 1) legend("topleft", c("Listed, remained open", "Listed, closed"), col = colors,
        pch = c(16, 17), lty = 1, bty = "n", cex = .75)
    }
  }
  mtext(if (weighting_method == "equal_transaction") "Raw annual prices: equal transaction weights" else
    "Raw annual prices: equal weight per observed site-year", outer = TRUE, side = 3, line = 1.5, cex = 1.25)
  mtext(if (design == "common") paste0("Fixed half-mile exclusions; identical site-years across bands. Gray band: 2013.\n", roster_label, " overall; yearly roster varies. Vertical scales vary by panel.") else
    "Any-site overlaps excluded at each band's outer radius. Gray band: 2013.\nDifferent sites contribute across bands and years; vertical scales vary by panel.",
    outer = TRUE, side = 1, line = .6, cex = .78)
  dev.off()
}

for (comparison in c("no_controls", "hedonics", "fixed_effects")) {
  png(paste0(if (design == "common") "../output/common_event_" else "../output/event_", comparison, ".png"), width = 2400, height = 2700, res = 220)
  par(mfrow = c(3, 2), mar = c(3.4, 4.2, 4, 1), oma = c(6, 0, 4, 0))
  for (index in 1:3) {
    for (outcome_name in c("dollars", "log")) {
      data <- copy(coefficients[ring == rings[index] & outcome == outcome_name & estimator == "event"])
      tests <- copy(summaries[ring == rings[index] & outcome == outcome_name & estimator == "event"])
      if (comparison == "fixed_effects") {
        data <- data[weighting == "equal_site_year" & specification %in% c("site_hedonics", "group_hedonics")]
        tests <- tests[weighting == "equal_site_year" & specification %in% c("site_hedonics", "group_hedonics")]
        data[, series := match(specification, c("site_hedonics", "group_hedonics"))]
        tests[, series := match(specification, c("site_hedonics", "group_hedonics"))]
        legend_labels <- c("School-site + year FE", "Treatment-group + year FE")
      } else {
        selected_spec <- if (comparison == "no_controls") "site_unadjusted" else "site_hedonics"
        data <- data[specification == selected_spec]
        tests <- tests[specification == selected_spec]
        data[, series := match(weighting, c("equal_transaction", "equal_site_year"))]
        tests[, series := match(weighting, c("equal_transaction", "equal_site_year"))]
        legend_labels <- c("Equal transaction", "Equal observed site-year")
      }
      divisor <- if (outcome_name == "dollars") 1000 else 1
      data[, `:=`(estimate = estimate / divisor, conf_low = conf_low / divisor, conf_high = conf_high / divisor)]
      limits <- range(c(0, data$conf_low, data$conf_high))
      plot(NA, xlim = c(2007.7, 2018.3), ylim = limits + c(-1, 1) * diff(limits) * .12, xaxt = "n", xlab = "",
        ylab = if (outcome_name == "dollars") "Effect (2022 $ thousands)" else "Effect (log points)", main = labels[index])
      axis(1, at = seq(2008, 2018, 2))
      rect(2012.5, par("usr")[3], 2013.5, par("usr")[4], col = "#eeeeee", border = NA)
      abline(h = 0, col = "#777777", lty = 2)
      for (group in 1:2) {
        series_data <- data[series == group][order(sale_year)]
        offset <- if (group == 1) -.1 else .1
        arrows(series_data$sale_year + offset, series_data$conf_low, series_data$sale_year + offset,
          series_data$conf_high, angle = 90, code = 3, length = .025, col = colors[group])
        points(series_data$sale_year + offset, series_data$estimate, pch = c(16, 17)[group], col = colors[group])
        points(2012 + offset, 0, pch = c(16, 17)[group], col = colors[group])
      }
      mtext(sprintf("Pre-period joint p: %.3f (blue), %.3f (orange)", tests[series == 1, pretrend_p],
        tests[series == 2, pretrend_p]), side = 3, line = .4, cex = .72)
      if (index == 1) legend("topleft", legend_labels, pch = c(16, 17), col = colors, bty = "n", cex = .7)
    }
  }
  title_text <- switch(comparison, no_controls = "Annual event studies: no housing controls",
    hedonics = "Annual event studies: housing controls", fixed_effects = "Annual event studies: fixed-effect comparison")
  mtext(paste0(title_text, if (design == "common") " — common sites" else ""), outer = TRUE, side = 3, line = 1.5, cex = 1.25)
  note <- if (comparison == "fixed_effects") "Housing controls; equal weight per observed site-year." else "School-site and year fixed effects."
  mtext(paste0(note, " 2012 reference; gray band: 2013.\n", if (design == "common") paste0("Fixed half-mile exclusions; identical site-years across bands; ", roster_label, ".\n95% site-clustered intervals; few treated sites. Pre-period tests cover 2008–2011.") else "95% intervals clustered by site. Any-site overlaps excluded; sites differ across bands.\nPre-period tests cover 2008–2011; passing a test does not establish parallel trends."),
    outer = TRUE, side = 1, line = 3, cex = .75)
  dev.off()
}

png(if (design == "common") "../output/common_did_by_ring.png" else "../output/did_by_ring.png", width = 2400, height = 1800, res = 220)
par(mfrow = c(2, 2), mar = c(4, 5.6, 3, 1), oma = c(5, 0, 3, 0))
for (weighting_method in c("equal_transaction", "equal_site_year")) {
  for (outcome_name in c("dollars", "log")) {
    data <- copy(coefficients[estimator == "did" & weighting == weighting_method & outcome == outcome_name &
      specification %in% c("site_hedonics", "group_hedonics")])
    divisor <- if (outcome_name == "dollars") 1000 else 1
    data[, `:=`(estimate = estimate / divisor, conf_low = conf_low / divisor, conf_high = conf_high / divisor,
      position = 6 - match(ring, rings))]
    limits <- range(c(0, data$conf_low, data$conf_high))
    plot(NA, xlim = limits + c(-1, 1) * diff(limits) * .08, ylim = c(.5, 6.2), yaxt = "n", ylab = "",
      xlab = if (outcome_name == "dollars") "Effect (2022 $ thousands)" else "Effect (log points)",
      main = if (weighting_method == "equal_transaction") "Equal transaction weights" else "Equal observed site-year weights")
    axis(2, at = 5:1, labels = labels, las = 1, tick = FALSE, cex.axis = .8)
    abline(v = 0, lty = 2, col = "#777777")
    abline(h = 2.5, lty = 3, col = "#aaaaaa")
    for (group in 1:2) {
      series <- data[specification == c("site_hedonics", "group_hedonics")[group]]
      position <- series$position + if (group == 1) .1 else -.1
      arrows(series$conf_low, position, series$conf_high, position, angle = 90, code = 3, length = .035, col = colors[group])
      points(series$estimate, position, col = colors[group], pch = c(16, 17)[group])
    }
    legend("top", c("School-site + year FE", "Treatment-group + year FE"), col = colors, pch = c(16, 17), bty = "n", cex = .72)
  }
}
mtext(if (design == "common") "DiD across distances: common sites and fixed exclusions" else "DiD across distance bands and cumulative buffers", outer = TRUE, side = 3, line = 1, cex = 1.25)
mtext(if (design == "common") paste0("Housing controls; 2008–2012 versus 2014–2018. 95% site-clustered intervals; ", roster_label, ".\nFixed half-mile exclusions; identical site-years across bands. Dotted divider: annuli / cumulative buffers.") else
  "Housing controls; 2008–2012 versus 2014–2018. 95% site-clustered intervals.\nDotted divider separates annuli (above) from cumulative buffers (below). Samples change with radius.",
  outer = TRUE, side = 1, line = 2, cex = .78)
dev.off()
