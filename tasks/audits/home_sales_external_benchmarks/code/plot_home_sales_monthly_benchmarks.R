suppressPackageStartupMessages(library(data.table))

monthly <- fread("../output/monthly_home_sales_benchmarks.csv")
correlations <- fread("../output/home_sales_external_correlations.csv")
monthly[, sale_month_date := as.IDate(sale_month_date)]

if (nrow(monthly) != 240L ||
    !identical(
      monthly$sale_month_date,
      seq(as.IDate("2006-01-01"), as.IDate("2025-12-01"), by = "month")
    )) {
  stop("Monthly benchmark table must contain every month from 2006 through 2025.", call. = FALSE)
}

price_scatter <- monthly[complete.cases(
  chicago_price_yoy_log_change,
  zillow_sale_price_yoy_log_change
)]
count_scatter <- monthly[complete.cases(
  chicago_sales_yoy_log_change,
  zillow_msa_sales_yoy_log_change
)]
monthly_price_correlation <- correlations[
  frequency == "monthly" &
    comparison == "Chicago median sale price vs Zillow city median sale price"
]
monthly_count_correlation <- correlations[
  frequency == "monthly" &
    comparison == "Chicago sales vs Zillow Chicago MSA sales"
]
if (nrow(monthly_price_correlation) != 1L || nrow(monthly_count_correlation) != 1L) {
  stop("Expected one monthly price and one monthly count correlation.", call. = FALSE)
}

png(
  "../output/home_sales_monthly_benchmarks.png",
  width = 2400,
  height = 1600,
  res = 180
)
par(mfrow = c(2, 3), mar = c(4.4, 4.7, 3.1, 1.0), oma = c(3.1, 0, 1.2, 0))

plot(
  monthly$sale_month_date,
  monthly$chicago_price_rolling_12_month / 1000,
  type = "l",
  lwd = 2,
  col = "#1B4F72",
  xlab = "Month",
  ylab = "Nominal dollars (thousands)",
  ylim = range(
    monthly$chicago_price_rolling_12_month,
    monthly$zillow_sale_price_rolling_12_month,
    monthly$zillow_zhvi_rolling_12_month,
    na.rm = TRUE
  ) / 1000,
  main = "Price levels, trailing 12 months"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_sale_price_rolling_12_month / 1000,
  lwd = 2,
  col = "#C0392B"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_zhvi_rolling_12_month / 1000,
  lwd = 2,
  col = "#D68910"
)
abline(v = as.Date("2013-01-01"), lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("Project median", "Zillow sales median", "Zillow ZHVI"),
  col = c("#1B4F72", "#C0392B", "#D68910"),
  lty = 1,
  lwd = 2,
  bty = "n",
  cex = 0.82
)

plot(
  monthly$sale_month_date,
  monthly$chicago_price_yoy_log_change,
  type = "l",
  lwd = 1.5,
  col = "#1B4F72",
  xlab = "Month",
  ylab = "12-month log change (percent)",
  ylim = range(
    monthly$chicago_price_yoy_log_change,
    monthly$zillow_sale_price_yoy_log_change,
    monthly$zillow_zhvi_yoy_log_change,
    na.rm = TRUE
  ),
  main = "Price growth"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_sale_price_yoy_log_change,
  lwd = 1.5,
  col = "#C0392B"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_zhvi_yoy_log_change,
  lwd = 1.5,
  col = "#D68910"
)
abline(h = 0, lty = 3, col = "grey70")
abline(v = as.Date("2013-01-01"), lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("Project median", "Zillow sales median", "Zillow ZHVI"),
  col = c("#1B4F72", "#C0392B", "#D68910"),
  lty = 1,
  lwd = 1.5,
  bty = "n",
  cex = 0.82
)

plot(
  monthly$sale_month_date,
  monthly$chicago_sales_rolling_index_2010,
  type = "l",
  lwd = 2,
  col = "#1B4F72",
  xlab = "Month",
  ylab = "Trailing-12-month index (2010 = 100)",
  ylim = range(
    monthly$chicago_sales_rolling_index_2010,
    monthly$zillow_msa_sales_rolling_index_2010,
    na.rm = TRUE
  ),
  main = "Sales activity"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_msa_sales_rolling_index_2010,
  lwd = 2,
  col = "#7D3C98"
)
abline(h = 100, lty = 3, col = "grey70")
abline(v = as.Date("2013-01-01"), lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("Project: Chicago city", "Zillow: Chicago MSA"),
  col = c("#1B4F72", "#7D3C98"),
  lty = 1,
  lwd = 2,
  bty = "n",
  cex = 0.82
)

plot(
  monthly$sale_month_date,
  monthly$chicago_sales_yoy_log_change,
  type = "l",
  lwd = 1.5,
  col = "#1B4F72",
  xlab = "Month",
  ylab = "12-month log change (percent)",
  ylim = range(
    monthly$chicago_sales_yoy_log_change,
    monthly$zillow_msa_sales_yoy_log_change,
    na.rm = TRUE
  ),
  main = "Sales-count growth"
)
lines(
  monthly$sale_month_date,
  monthly$zillow_msa_sales_yoy_log_change,
  lwd = 1.5,
  col = "#7D3C98"
)
abline(h = 0, lty = 3, col = "grey70")
abline(v = as.Date("2013-01-01"), lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("Project: Chicago city", "Zillow: Chicago MSA"),
  col = c("#1B4F72", "#7D3C98"),
  lty = 1,
  lwd = 1.5,
  bty = "n",
  cex = 0.82
)

plot(
  price_scatter$zillow_sale_price_yoy_log_change,
  price_scatter$chicago_price_yoy_log_change,
  pch = 16,
  col = rgb(27, 79, 114, 130, maxColorValue = 255),
  xlab = "Zillow city price growth (percent)",
  ylab = "Project price growth (percent)",
  main = sprintf(
    "Monthly price-growth comparison\nPearson r = %.2f; Spearman rho = %.2f",
    monthly_price_correlation$pearson_correlation,
    monthly_price_correlation$spearman_correlation
  )
)
abline(lm(
  chicago_price_yoy_log_change ~ zillow_sale_price_yoy_log_change,
  data = price_scatter
), col = "#C0392B", lwd = 2)
abline(a = 0, b = 1, lty = 3, col = "grey55")

plot(
  count_scatter$zillow_msa_sales_yoy_log_change,
  count_scatter$chicago_sales_yoy_log_change,
  pch = 16,
  col = rgb(27, 79, 114, 130, maxColorValue = 255),
  xlab = "Zillow MSA sales growth (percent)",
  ylab = "Project Chicago sales growth (percent)",
  main = sprintf(
    "Monthly sales-growth comparison\nPearson r = %.2f; Spearman rho = %.2f",
    monthly_count_correlation$pearson_correlation,
    monthly_count_correlation$spearman_correlation
  )
)
abline(lm(
  chicago_sales_yoy_log_change ~ zillow_msa_sales_yoy_log_change,
  data = count_scatter
), col = "#7D3C98", lwd = 2)
abline(a = 0, b = 1, lty = 3, col = "grey55")

mtext(
  "Price series cover Chicago city. Zillow sales counts cover the Chicago MSA. ZHVI measures modeled stock values. The vertical line marks 2013.",
  side = 1,
  outer = TRUE,
  line = 1.0,
  cex = 0.82
)
dev.off()
