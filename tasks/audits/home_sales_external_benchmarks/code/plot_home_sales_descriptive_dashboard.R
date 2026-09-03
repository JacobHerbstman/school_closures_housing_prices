suppressPackageStartupMessages(library(data.table))

annual <- fread("../output/annual_home_sales_benchmarks.csv")
if (!identical(annual$sale_year, 2006:2025)) {
  stop("Annual benchmark table must be sorted from 2006 through 2025.", call. = FALSE)
}
if (any(
  annual$cleaned_sales !=
    annual$one_unit_or_rowhouse_sales +
      annual$two_to_six_unit_sales +
      annual$small_mixed_use_sales +
      annual$condominium_sales
)) {
  stop("Annual property groups do not reproduce total clean sales.", call. = FALSE)
}

colors <- c(
  "#1B4F72",
  "#7D3C98",
  "#1E8449",
  "#D68910",
  "#C0392B"
)
group_labels <- c(
  "1-unit/rowhouse",
  "2-6-unit class 211",
  "Small mixed-use class 212",
  "Condominium class 299"
)

png(
  "../output/home_sales_descriptive_dashboard.png",
  width = 2400,
  height = 1600,
  res = 180
)
par(mfrow = c(2, 3), mar = c(4.4, 4.7, 3.1, 1.0), oma = c(3.1, 0, 1.2, 0))

matplot(
  annual$sale_year,
  cbind(
    annual$one_unit_or_rowhouse_sales,
    annual$two_to_six_unit_sales,
    annual$small_mixed_use_sales,
    annual$condominium_sales
  ) / 1000,
  type = "o",
  pch = c(16, 17, 15, 1),
  lty = 1,
  col = colors,
  xlab = "Year",
  ylab = "Transactions (thousands)",
  main = "Sales by property group"
)
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = group_labels,
  col = colors,
  pch = c(16, 17, 15, 1),
  lty = 1,
  bty = "n",
  cex = 0.78
)

matplot(
  annual$sale_year,
  cbind(
    annual$median_one_unit_or_rowhouse_price,
    annual$median_two_to_six_unit_price,
    annual$median_small_mixed_use_price,
    annual$median_condo_sale_price
  ) / 1000,
  type = "o",
  pch = c(16, 17, 15, 1),
  lty = 1,
  col = colors,
  xlab = "Year",
  ylab = "Nominal median price (thousands)",
  main = "Median price by property group"
)
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = group_labels,
  col = colors,
  pch = c(16, 17, 15, 1),
  lty = 1,
  bty = "n",
  cex = 0.78
)

plot(
  annual$sale_year,
  annual$median_sale_price / 1000,
  type = "n",
  xlab = "Year",
  ylab = "Nominal sale price (thousands)",
  ylim = range(annual$sale_price_p10, annual$sale_price_p90) / 1000,
  main = "Sale-price distribution"
)
polygon(
  c(annual$sale_year, rev(annual$sale_year)),
  c(annual$sale_price_p10, rev(annual$sale_price_p90)) / 1000,
  col = rgb(27, 79, 114, 35, maxColorValue = 255),
  border = NA
)
polygon(
  c(annual$sale_year, rev(annual$sale_year)),
  c(annual$sale_price_p25, rev(annual$sale_price_p75)) / 1000,
  col = rgb(27, 79, 114, 75, maxColorValue = 255),
  border = NA
)
lines(annual$sale_year, annual$median_sale_price / 1000, lwd = 2, col = "#1B4F72")
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "topleft",
  legend = c("10th-90th percentile", "25th-75th percentile", "Median"),
  fill = c(
    rgb(27, 79, 114, 35, maxColorValue = 255),
    rgb(27, 79, 114, 75, maxColorValue = 255),
    NA
  ),
  border = c(NA, NA, NA),
  lty = c(NA, NA, 1),
  col = c(NA, NA, "#1B4F72"),
  bty = "n",
  cex = 0.8
)

property_shares <- rbind(
  0,
  annual$one_unit_or_rowhouse_share,
  annual$one_unit_or_rowhouse_share + annual$two_to_six_unit_building_share,
  annual$one_unit_or_rowhouse_share +
    annual$two_to_six_unit_building_share +
    annual$mixed_use_small_residential_share,
  1
)
plot(
  annual$sale_year,
  annual$one_unit_or_rowhouse_share * 100,
  type = "n",
  xlab = "Year",
  ylab = "Percent of cleaned transactions",
  ylim = c(0, 100),
  main = "Property composition"
)
for (group_index in 1:4) {
  polygon(
    c(annual$sale_year, rev(annual$sale_year)),
    c(property_shares[group_index, ], rev(property_shares[group_index + 1L, ])) * 100,
    col = colors[group_index],
    border = NA
  )
}
abline(v = 2013, lty = 3, col = "white")
legend(
  "bottomleft",
  legend = group_labels,
  fill = colors,
  border = NA,
  bty = "n",
  cex = 0.76
)

plot(
  annual$sale_year,
  annual$verified_parking_share_of_condos * 100,
  type = "o",
  pch = 16,
  lwd = 2,
  col = "#D68910",
  xlab = "Year",
  ylab = "Percent of condominium transactions",
  ylim = c(0, max(annual$verified_parking_share_of_condos * 100) * 1.1),
  main = "Verified condo-plus-parking bundles"
)
abline(v = 2013, lty = 3, col = "grey55")

matplot(
  annual$sale_year,
  cbind(
    annual$same_sale_within_365_flagged_share,
    annual$less_than_10k_flagged_share,
    annual$deed_type_flagged_share,
    annual$clean_retention_share,
    annual$idor_refined_date_share
  ) * 100,
  type = "o",
  pch = c(16, 17, 15, 1, 2),
  lty = 1,
  col = colors,
  xlab = "Year",
  ylab = "Percent",
  ylim = c(0, 100),
  main = "Filters, retention, and date precision"
)
abline(v = 2013, lty = 3, col = "grey55")
legend(
  "bottomright",
  legend = c(
    "CCAO same-sale-within-365 flag / raw",
    "CCAO less-than-$10k flag / raw",
    "CCAO deed-type flag / raw",
    "Final clean / residential raw",
    "IDOR-refined transaction date / final clean"
  ),
  col = colors,
  pch = c(16, 17, 15, 1, 2),
  lty = 1,
  bty = "n",
  cex = 0.69
)

mtext(
  "Nominal prices. No observations are removed by this audit. The vertical line marks 2013.",
  side = 1,
  outer = TRUE,
  line = 1.0,
  cex = 0.82
)
dev.off()
