suppressPackageStartupMessages(library(data.table))
audit <- readRDS("../output/sample_reconciliation.rds")
monthly <- audit$monthly
annual <- audit$annual
png("../output/sample_comparison.png", width = 1800, height = 1250, res = 160)
par(mfrow = c(2, 3), mar = c(4, 4.5, 3, 1), oma = c(2.5, 0, 2, 0), las = 1, bty = "l")
colors <- c(old = "#858585", new = "#15616D")
for (field in c("median_price", "median_ppsf", "median_sqft", "multifamily_share")) {
  title <- switch(field, median_price = "Monthly median sale price", median_ppsf = "Monthly median price per sq. ft.",
                  median_sqft = "Monthly median building area", multifamily_share = "Monthly two-to-six-unit share")
  label <- switch(field, median_price = "Nominal $1,000s", median_ppsf = "Nominal dollars / sq. ft.",
                  median_sqft = "Square feet", multifamily_share = "Share of sales")
  scale <- ifelse(field == "median_price", 1000, 1)
  plot(range(monthly$month), range(monthly[[field]]) / scale, type = "n", xlab = "", ylab = label, main = title)
  for (version_name in c("old", "new")) {
    series <- monthly[version == version_name][order(month)]
    lines(series$month, series[[field]] / scale, col = colors[version_name], lwd = 1.6,
          lty = ifelse(version_name == "old", 1, 2))
  }
  if (field == "median_price") legend("topleft", c("Before corrections", "Corrected, consistent sample"),
                                      col = colors, lty = c(1, 2), lwd = 1.6, bty = "n", cex = .8)
}
year_counts <- dcast(annual, sale_year ~ version, value.var = "sales")
plot(year_counts$sale_year, 100 * (year_counts$new / year_counts$old - 1), type = "b", pch = 16,
     col = colors["new"], xlab = "Year", ylab = "Percent", main = "Change in retained sales")
abline(h = 0, col = "#BBBBBB", lty = 3)
neighborhoods <- audit$neighborhoods
plot(neighborhoods$sales_old, neighborhoods$share_change_pct, pch = 16, cex = .55,
     col = adjustcolor(colors["new"], .6), xlab = "Original neighborhood sample size", ylab = "Percent change",
     main = "Selection change by assessor neighborhood")
abline(h = 0, col = "#BBBBBB", lty = 3)
mtext("Housing sample reconciliation | Chicago, 2008–2018", outer = TRUE, side = 3, cex = 1.1, font = 2)
mtext("Same source transactions and existing price rules. Dashed teal overlays gray where series agree. No inflation adjustment or new trimming.",
      outer = TRUE, side = 1, cex = .75)
dev.off()
