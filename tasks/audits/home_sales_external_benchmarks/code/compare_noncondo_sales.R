suppressPackageStartupMessages(library(data.table))

master <- fread("../input/corrected_home_sale_characteristics_2006_2025.csv",
                colClasses = list(character = c("row_id", "pin")))
clean <- fread("../input/home_sales_2008_2018.csv",
               colClasses = list(character = c("row_id", "pin")))
external <- fread("../output/external_home_market_benchmarks.csv")
stopifnot(!anyDuplicated(master$row_id), !anyDuplicated(clean$row_id),
          all(clean$row_id %in% master$row_id), nrow(clean) > 0L)

# Broad market sales retain multicard, mixed-use, and incomplete-hedonic cases.
# The master has already excluded condos and multi-PIN transactions.
market <- master[
  !sale_filter_same_sale_within_365 & !sale_filter_less_than_10k &
    !sale_filter_deed_type & is.finite(sale_price_nominal) &
    sale_price_nominal > 10000 & !is.na(sale_type) & sale_type != "LAND"
]
stopifnot(all(clean$row_id %in% market$row_id),
          !any(market$property_class == 299L), !any(clean$analysis_class == 299L))
columns <- c("row_id", "pin", "sale_year", "sale_month", "sale_price_nominal")
sales <- rbindlist(list(
  broad_noncondo = market[, ..columns],
  final_price_sample = clean[, ..columns],
  final_single_family = clean[analysis_property_type == "single_family", ..columns]
), idcol = "sample")
stopifnot(!anyDuplicated(sales[, .(sample, row_id)]))
sales[, month := as.IDate(sprintf("%d-%02d-01", sale_year, sale_month))]
monthly <- sales[, .(sales = .N, median_price = median(sale_price_nominal)),
                 by = .(sample, month)]
setorder(monthly, sample, month)
stopifnot(identical(monthly[sample == "broad_noncondo", month],
                    seq(as.IDate("2006-01-01"), as.IDate("2025-12-01"), by = "month")),
          identical(monthly[sample == "final_price_sample", month],
                    seq(as.IDate("2008-01-01"), as.IDate("2018-12-01"), by = "month")))

zillow <- external[source == "Zillow", .(
  month = as.IDate(paste0(substr(period, 1, 7), "-01")), series, value
)]
stopifnot(!anyDuplicated(zillow[, .(month, series)]))
zillow <- dcast(zillow, month ~ series, value.var = "value")
setnames(zillow, c("median_sale_price", "home_value_index", "sales_count_nowcast"),
         c("zillow_median_price", "zillow_zhvi", "zillow_msa_sales"))
# Many sample-months to one Zillow month. All project rows must survive.
rows_before <- nrow(monthly)
monthly <- merge(monthly, zillow, by = "month", all.x = TRUE, sort = FALSE)
stopifnot(nrow(monthly) == rows_before, !anyDuplicated(monthly[, .(sample, month)]),
          all(is.finite(monthly$zillow_zhvi)),
          all(is.finite(monthly[month >= as.IDate("2009-01-01"), zillow_median_price])),
          all(is.finite(monthly[month >= as.IDate("2009-01-01"), zillow_msa_sales])))
setorder(monthly, sample, month)
monthly[, `:=`(
  price_yoy = 100 * (log(median_price) - shift(log(median_price), 12L)),
  sales_yoy = 100 * (log(sales) - shift(log(sales), 12L)),
  zillow_price_yoy = 100 * (log(zillow_median_price) - shift(log(zillow_median_price), 12L)),
  zillow_zhvi_yoy = 100 * (log(zillow_zhvi) - shift(log(zillow_zhvi), 12L)),
  zillow_sales_yoy = 100 * (log(zillow_msa_sales) - shift(log(zillow_msa_sales), 12L)),
  price_12m = frollmean(median_price, 12L, align = "right"),
  zillow_price_12m = frollmean(zillow_median_price, 12L, align = "right"),
  zillow_zhvi_12m = frollmean(zillow_zhvi, 12L, align = "right"),
  sales_12m = frollsum(sales, 12L, align = "right"),
  zillow_sales_12m = frollsum(zillow_msa_sales, 12L, align = "right")
), by = sample]
# Normalize each trailing series to its own mean during calendar 2010.
monthly[, `:=`(
  price_index = 100 * price_12m / mean(price_12m[format(month, "%Y") == "2010"]),
  sales_index = 100 * sales_12m / mean(sales_12m[format(month, "%Y") == "2010"]),
  zillow_price_index = 100 * zillow_price_12m / mean(zillow_price_12m[format(month, "%Y") == "2010"]),
  zillow_sales_index = 100 * zillow_sales_12m / mean(zillow_sales_12m[format(month, "%Y") == "2010"])
), by = sample]
fwrite(monthly, "../output/noncondo_monthly_benchmarks.csv")

# Use a common window across samples, allowing a full year for growth rates.
comparisons <- data.table(
  comparison = c("Sale price level", "Sale price growth", "ZHVI growth", "Sales-count growth"),
  project = c("median_price", "price_yoy", "price_yoy", "sales_yoy"),
  benchmark = c("zillow_median_price", "zillow_price_yoy", "zillow_zhvi_yoy", "zillow_sales_yoy")
)
correlations <- list()
for (sample_name in unique(monthly$sample)) {
  for (i in seq_len(nrow(comparisons))) {
    first_month <- if (i == 1L) as.IDate("2008-02-01") else as.IDate("2009-02-01")
    pairs <- monthly[sample == sample_name & month >= first_month &
                       month <= as.IDate("2018-12-01"),
                     .(month, project = get(comparisons$project[i]),
                       benchmark = get(comparisons$benchmark[i]))]
    pairs <- pairs[is.finite(project) & is.finite(benchmark)]
    stopifnot(nrow(pairs) >= 100L)
    correlations[[length(correlations) + 1L]] <- data.table(
      sample = sample_name, comparison = comparisons$comparison[i],
      first_month = min(pairs$month), last_month = max(pairs$month), months = nrow(pairs),
      pearson = cor(pairs$project, pairs$benchmark),
      spearman = cor(pairs$project, pairs$benchmark, method = "spearman")
    )
  }
}
correlations <- rbindlist(correlations)
fwrite(correlations, "../output/noncondo_external_correlations.csv")

# ACS 2024 is a contextual stock comparison for the broad 2024 transaction
# sample. It cannot validate the 2008-2018 sample or identify condo ownership.
acs <- external[source == "ACS 1-year"]
stopifnot(all(acs$period == "2024"), !anyDuplicated(acs$series))
acs_values <- setNames(acs$value, acs$series)
market_2024 <- market[sale_year == 2024L]
acs_comparison <- data.table(
  statistic = c("Median value or transaction price", "One-unit share", "Two-to-six-unit building share", "Mixed-use building share"),
  broad_noncondo_2024 = c(median(market_2024$sale_price_nominal),
                         mean(market_2024$property_class %in% c(202:210, 234, 278, 295)),
                         mean(market_2024$property_class == 211L),
                         mean(market_2024$property_class == 212L)),
  acs_owner_occupied_2024 = c(acs_values[["median_owner_occupied_value"]],
    (acs_values[["owner_occupied_one_unit_detached"]] + acs_values[["owner_occupied_one_unit_attached"]]) /
      acs_values[["owner_occupied_units_total"]], NA_real_, NA_real_),
  caveat = c("Nominal transaction prices versus self-reported owner-occupied stock values",
             "Transactions versus occupied units; ACS includes condos and excludes renter-occupied units",
             "ACS structural bins do not isolate two-to-six-unit building transactions",
             "No directly comparable ACS ownership/structure category")
)
fwrite(acs_comparison, "../output/noncondo_acs_comparison.csv")

plot_months <- monthly[month %between% as.IDate(c("2008-01-01", "2018-12-01"))]
labels <- c(broad_noncondo = "Broad non-condo market sales", final_price_sample = "Final price sample",
            final_single_family = "Final single-family only")
colors <- c(broad_noncondo = "#7F8C8D", final_price_sample = "#176B87", final_single_family = "#419D78")
benchmark <- plot_months[sample == "final_price_sample"]
png("../output/noncondo_external_benchmarks.png", width = 2200, height = 1600, res = 200)
par(mfrow = c(2, 2), mar = c(4, 5, 3, 1), oma = c(4.5, 0, 2, 0))
for (panel in 1:4) {
  field <- c("price_12m", "price_index", "price_yoy", "sales_index")[panel]
  external_field <- c("zillow_price_12m", "zillow_price_index", "zillow_price_yoy", "zillow_sales_index")[panel]
  scale <- if (panel == 1L) 1000 else 1
  limits <- range(c(plot_months[[field]], benchmark[[external_field]],
                    if (panel == 1L) benchmark$zillow_zhvi_12m), na.rm = TRUE) / scale
  plot(range(plot_months$month), limits, type = "n", xlab = "Year",
       ylab = c("Nominal dollars (thousands)", "2010 = 100", "12-month log change (%)", "2010 = 100")[panel],
       main = c("Median prices: trailing 12-month average", "Price trends: trailing 12-month average",
                "Year-over-year median price changes", "Sales activity: trailing 12-month total")[panel])
  for (sample_name in names(labels)) {
    series <- plot_months[sample == sample_name]
    lines(series$month, series[[field]] / scale, col = colors[sample_name], lwd = 1.8)
  }
  lines(benchmark$month, benchmark[[external_field]] / scale, col = "#C44E52", lwd = 1.8, lty = 2)
  if (panel == 1L) lines(benchmark$month, benchmark$zillow_zhvi_12m / scale, col = "#C99700", lwd = 1.8, lty = 3)
  abline(v = as.IDate("2013-01-01"), col = "grey65", lty = 3)
  if (panel == 1L) legend("topleft", c(unname(labels), "Zillow city sales median", "Zillow city ZHVI"),
                         col = c(colors, "#C44E52", "#C99700"), lty = c(1, 1, 1, 2, 3),
                         lwd = 1.8, cex = .65, bty = "n")
  if (panel == 4L) legend("topleft", c(unname(labels), "Zillow Chicago MSA sales"),
                         col = c(colors, "#C44E52"), lty = c(1, 1, 1, 2), lwd = 1.8, cex = .65, bty = "n")
}
mtext("Chicago non-condo sales | external benchmarks, 2008–2018", side = 3, outer = TRUE, font = 2, line = .5)
mtext("Zillow price series include houses and condos; its sales counts cover the metropolitan area. ZHVI measures stock values.",
      side = 1, outer = TRUE, line = 1.3, cex = .75)
mtext("Prices are nominal to match Zillow. Final samples exclude sales above the within-year 99.9th percentile of price per square foot.",
      side = 1, outer = TRUE, line = 2.6, cex = .72)
dev.off()
print(correlations)
print(acs_comparison)
