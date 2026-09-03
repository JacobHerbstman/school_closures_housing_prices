suppressPackageStartupMessages(library(data.table))

annual <- fread("../output/annual_home_sales_benchmarks.csv")
composition <- fread("../output/home_sales_composition_2024.csv")

if (!identical(annual$sale_year, 2006:2025)) {
  stop("Annual benchmark table must be sorted from 2006 through 2025.", call. = FALSE)
}

png(
  "../output/home_sales_external_benchmarks.png",
  width = 2000,
  height = 1500,
  res = 180
)
par(mfrow = c(2, 2), mar = c(4.5, 4.8, 3.2, 1.2), oma = c(2.5, 0, 0, 0))

price_range <- range(
  annual$median_sale_price,
  annual$legacy_restricted_median_price,
  annual$zillow_median_sale_price,
  annual$zillow_zhvi,
  annual$acs_median_owner_occupied_value,
  na.rm = TRUE
)
plot(
  annual$sale_year,
  annual$median_sale_price / 1000,
  type = "o",
  pch = 16,
  col = "#1B4F72",
  xlab = "Year",
  ylab = "Nominal dollars (thousands)",
  ylim = price_range / 1000,
  main = "Chicago home-price levels"
)
lines(
  annual$sale_year,
  annual$legacy_restricted_median_price / 1000,
  type = "o",
  pch = 2,
  lty = 2,
  col = "#2874A6"
)
lines(
  annual$sale_year,
  annual$zillow_median_sale_price / 1000,
  type = "o",
  pch = 1,
  col = "#C0392B"
)
lines(annual$sale_year, annual$zillow_zhvi / 1000, lwd = 2, col = "#D68910")
points(
  2024,
  annual[sale_year == 2024L, acs_median_owner_occupied_value] / 1000,
  pch = 17,
  cex = 1.2,
  col = "#1E8449"
)
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c(
    "Chicago baseline",
    "Chicago under old rules",
    "Zillow sales median",
    "Zillow ZHVI",
    "ACS 2024 median value"
  ),
  col = c("#1B4F72", "#2874A6", "#C0392B", "#D68910", "#1E8449"),
  pch = c(16, 2, 1, NA, 17),
  lty = c(1, 2, 1, 1, NA),
  bty = "n",
  cex = 0.82
)

plot(
  annual$sale_year,
  annual$sale_price_index_2010,
  type = "o",
  pch = 16,
  col = "#1B4F72",
  xlab = "Year",
  ylab = "Index (2010 = 100)",
  ylim = range(
    annual$sale_price_index_2010,
    annual$legacy_sale_price_index_2010,
    annual$zillow_sale_price_index_2010,
    annual$zillow_zhvi_index_2010,
    na.rm = TRUE
  ),
  main = "Price trends"
)
lines(
  annual$sale_year,
  annual$legacy_sale_price_index_2010,
  type = "o",
  pch = 2,
  lty = 2,
  col = "#2874A6"
)
lines(
  annual$sale_year,
  annual$zillow_sale_price_index_2010,
  type = "o",
  pch = 1,
  col = "#C0392B"
)
lines(annual$sale_year, annual$zillow_zhvi_index_2010, lwd = 2, col = "#D68910")
abline(h = 100, lty = 3, col = "grey70")
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("Chicago baseline", "Chicago under old rules", "Zillow sales median", "Zillow ZHVI"),
  col = c("#1B4F72", "#2874A6", "#C0392B", "#D68910"),
  pch = c(16, 2, 1, NA),
  lty = c(1, 2, 1, 1),
  bty = "n",
  cex = 0.85
)

plot(
  annual$sale_year,
  annual$sales_count_index_2010,
  type = "o",
  pch = 16,
  col = "#1B4F72",
  xlab = "Year",
  ylab = "Index (2010 = 100)",
  ylim = range(
    annual$sales_count_index_2010,
    annual$legacy_restricted_sales_count_index_2010,
    annual$zillow_msa_sales_count_index_2010,
    na.rm = TRUE
  ),
  main = "Sales activity"
)
lines(
  annual$sale_year,
  annual$legacy_restricted_sales_count_index_2010,
  type = "o",
  pch = 2,
  lty = 2,
  col = "#2874A6"
)
lines(
  annual$sale_year,
  annual$zillow_msa_sales_count_index_2010,
  type = "o",
  pch = 1,
  col = "#7D3C98"
)
abline(h = 100, lty = 3, col = "grey70")
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c(
    "Chicago baseline",
    "Chicago under old rules",
    "Zillow Chicago MSA"
  ),
  col = c("#1B4F72", "#2874A6", "#7D3C98"),
  pch = c(16, 2, 1),
  lty = c(1, 2, 1),
  bty = "n",
  cex = 0.85
)

composition[, label := fcase(
  category == "One-unit residence or rowhouse", "Chicago: 1-unit/rowhouse",
  category == "Two-to-six-unit building class 211", "Chicago: 2-6-unit building",
  category == "Small mixed-use residential class 212", "Chicago: small mixed-use",
  category == "Condominium class 299", "Chicago: condominium",
  category == "One-unit detached or attached", "ACS: 1-unit",
  category == "Two-to-four-unit structure", "ACS: 2-4-unit",
  category == "Five-or-more-unit structure", "ACS: 5+-unit",
  category == "Mobile home, boat, RV, or other", "ACS: other"
)]
if (anyNA(composition$label)) {
  stop("Composition table contains an unexpected category.", call. = FALSE)
}
barplot(
  rev(composition$share * 100),
  names.arg = rev(composition$label),
  horiz = TRUE,
  las = 1,
  col = rev(ifelse(grepl("^Chicago", composition$label), "#1B4F72", "#1E8449")),
  border = NA,
  xlab = "Percent",
  main = "2024 composition: transactions versus stock",
  cex.names = 0.72
)

mtext(
  "Nominal prices. ACS is owner-occupied stock; Zillow sales counts cover the MSA; Chicago classes 211 and 212 are building transactions.",
  side = 1,
  outer = TRUE,
  line = 0.6,
  cex = 0.78
)
dev.off()
