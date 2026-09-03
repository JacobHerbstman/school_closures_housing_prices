suppressPackageStartupMessages(library(data.table))

cases <- fread(
  "../output/residential_multicard_pin_years.csv",
  colClasses = list(character = "pin")
)
by_class <- fread("../output/residential_multicard_by_class.csv")
clean_sales <- fread(
  "../input/home_sales_2006_2025.csv",
  select = c("row_id", "pin", "sale_year", "property_type"),
  colClasses = list(character = c("row_id", "pin"))
)

if (nrow(cases) == 0L || anyDuplicated(cases[, .(pin, year)]) > 0L) {
  stop("Multicard case table must contain unique PIN-years.", call. = FALSE)
}

cases[, card_count_group := fifelse(
  card_count >= 11L,
  "11+",
  as.character(card_count)
)]
card_count_table <- cases[, .N, by = card_count_group]
card_count_table[, card_count_group := factor(
  card_count_group,
  levels = c(as.character(2:10), "11+")
)]
setorder(card_count_table, card_count_group)

class_plot <- by_class[!is.na(property_class)]
setorder(class_plot, multicard_pin_year_share)

clean_noncondo <- clean_sales[property_type != "condominium"]
clean_by_year <- clean_noncondo[, .(clean_sales = .N), by = sale_year]
clean_noncondo[, year := sale_year]
clean_multicard <- merge(
  clean_noncondo,
  cases[, .(pin, year)],
  by = c("pin", "year"),
  all = FALSE,
  sort = FALSE
)
clean_multicard_by_year <- clean_multicard[, .(
  clean_multicard_sales = .N
), by = sale_year]
clean_by_year <- merge(
  clean_by_year,
  clean_multicard_by_year,
  by = "sale_year",
  all.x = TRUE,
  sort = TRUE
)
clean_by_year[is.na(clean_multicard_sales), clean_multicard_sales := 0L]
clean_by_year[, multicard_share := clean_multicard_sales / clean_sales]

png(
  "../output/residential_multicard_improvements.png",
  width = 2000,
  height = 1500,
  res = 180
)
par(mfrow = c(2, 2), mar = c(4.5, 4.8, 3.2, 1.0), oma = c(2.7, 0, 0, 0))

barplot(
  card_count_table$N,
  names.arg = card_count_table$card_count_group,
  col = "#1B4F72",
  border = NA,
  xlab = "Improvement cards in PIN-year",
  ylab = "PIN-years",
  main = "Card-count distribution"
)

barplot(
  rev(class_plot$multicard_pin_year_share * 100),
  names.arg = rev(class_plot$property_class_label),
  horiz = TRUE,
  las = 1,
  col = "#7D3C98",
  border = NA,
  xlab = "Percent of master PIN-years",
  main = "Multicard incidence by transaction class",
  cex.names = 0.78
)

hist(
  cases$largest_building_share,
  breaks = seq(0, 1, by = 0.05),
  col = "#1E8449",
  border = "white",
  xlab = "Largest card's share of summed building square footage",
  ylab = "PIN-years",
  main = "Dominance of the largest card"
)
abline(v = median(cases$largest_building_share, na.rm = TRUE), lwd = 2, col = "#C0392B")

plot(
  clean_by_year$sale_year,
  clean_by_year$multicard_share * 100,
  type = "o",
  pch = 16,
  lwd = 2,
  col = "#D68910",
  xlab = "Year",
  ylab = "Percent of clean non-condo sales",
  ylim = c(0, max(clean_by_year$multicard_share * 100) * 1.1),
  main = "Multicard share of the clean sample"
)
abline(v = 2013, lty = 3, col = "grey55")

mtext(
  "Audit only. No sales or cards are removed, selected, or aggregated.",
  side = 1,
  outer = TRUE,
  line = 0.8,
  cex = 0.82
)
dev.off()
