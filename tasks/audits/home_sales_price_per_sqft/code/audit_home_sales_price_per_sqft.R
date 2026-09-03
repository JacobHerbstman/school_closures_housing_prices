suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript audit_home_sales_price_per_sqft.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

sales_file <- sprintf("../input/home_sales_%d_%d.csv", start_year, end_year)
condo_file <- sprintf(
  "../input/condo_sale_characteristics_%d_%d.csv",
  start_year,
  end_year
)
improvement_file <- sprintf(
  "../output/sale_improvement_characteristics_%d_%d.csv",
  start_year,
  end_year
)
summary_file <- sprintf(
  "../output/home_sales_price_per_sqft_summary_%d_%d.csv",
  start_year,
  end_year
)
extremes_file <- sprintf(
  "../output/home_sales_price_per_sqft_extremes_%d_%d.csv",
  start_year,
  end_year
)
plot_file <- sprintf(
  "../output/home_sales_price_per_sqft_%d_%d.png",
  start_year,
  end_year
)

sales <- fread(
  sales_file,
  select = c(
    "row_id", "sale_document_num", "pin", "parking_pin", "sale_date",
    "sale_year", "sale_price_nominal", "sale_price_prorated_nominal",
    "includes_deeded_parking_pin", "sale_sample_rule", "property_class",
    "property_type", "num_parcels_sale"
  ),
  colClasses = list(character = c(
    "row_id", "sale_document_num", "pin", "parking_pin", "sale_date"
  ))
)
if (nrow(sales) == 0L || anyDuplicated(sales$row_id) > 0L) {
  stop("Home sales must contain records uniquely keyed by row_id.", call. = FALSE)
}

improvements <- fread(
  improvement_file,
  colClasses = list(character = "pin")
)
if (anyDuplicated(improvements[, .(pin, year, card)]) > 0L) {
  stop("Improvement characteristics must be unique by PIN, year, and card.", call. = FALSE)
}

# House size is used only when the PIN-year has exactly one improvement card.
# This avoids attributing a bundled sale price to one of several buildings.
house_sizes <- improvements[, .(
  square_feet = if (
    .N == 1L &&
      pin_is_multicard[1L] %in% FALSE &&
      pin_num_cards[1L] == 1L &&
      is.finite(building_sqft[1L]) &&
      building_sqft[1L] > 0
  ) as.numeric(building_sqft[1L]) else NA_real_,
  size_record_count = .N,
  square_feet_source = "single_improvement_card"
), by = .(pin, sale_year = year)]
house_sizes[, property_type := "house_or_small_residential"]

condo_characteristics <- fread(
  condo_file,
  colClasses = list(character = "pin")
)
if (anyDuplicated(condo_characteristics[, .(pin, year)]) > 0L) {
  stop("Condo characteristics must be unique by PIN and year.", call. = FALSE)
}
condo_sizes <- condo_characteristics[
  is_parking_space %in% FALSE & is_common_area %in% FALSE,
  .(
    pin,
    sale_year = year,
    square_feet = fifelse(
      is.finite(condo_unit_sqft) & condo_unit_sqft > 0,
      condo_unit_sqft,
      NA_real_
    ),
    size_record_count = 1L,
    square_feet_source = "condo_unit_characteristics",
    property_type = "condominium"
  )
]

size_records <- rbindlist(
  list(house_sizes, condo_sizes),
  use.names = TRUE,
  fill = TRUE
)
if (anyDuplicated(size_records[, .(pin, sale_year, property_type)]) > 0L) {
  stop("Sale-linked size records are not unique by PIN-year and property type.", call. = FALSE)
}

# The sales-to-size merge is many-to-one on PIN, sale year, and property type.
sales_with_size <- merge(
  sales,
  size_records,
  by = c("pin", "sale_year", "property_type"),
  all.x = TRUE,
  sort = FALSE
)
if (nrow(sales_with_size) != nrow(sales) ||
    anyDuplicated(sales_with_size$row_id) > 0L) {
  stop("The size merge changed the number or identity of sale records.", call. = FALSE)
}

sales_with_size[, has_usable_square_feet :=
  is.finite(square_feet) & square_feet > 0]
sales_with_size[, price_per_sqft_total := fifelse(
  has_usable_square_feet,
  sale_price_nominal / square_feet,
  NA_real_
)]
sales_with_size[, price_per_sqft_prorated := fifelse(
  has_usable_square_feet,
  sale_price_prorated_nominal / square_feet,
  NA_real_
)]

cat(sprintf(
  "Usable square footage is available for %s of %s sales (%.2f percent).\n",
  format(sum(sales_with_size$has_usable_square_feet), big.mark = ","),
  format(nrow(sales_with_size), big.mark = ","),
  100 * mean(sales_with_size$has_usable_square_feet)
))

summary <- sales_with_size[, {
  observed_price_per_sqft <- price_per_sqft_total[is.finite(price_per_sqft_total)]
  list(
    sales = .N,
    sales_with_usable_square_feet = length(observed_price_per_sqft),
    square_feet_coverage = length(observed_price_per_sqft) / .N,
    price_per_sqft_p01 = if (length(observed_price_per_sqft) > 0L) {
      as.numeric(quantile(observed_price_per_sqft, 0.01, names = FALSE))
    } else NA_real_,
    price_per_sqft_p50 = if (length(observed_price_per_sqft) > 0L) {
      median(observed_price_per_sqft)
    } else NA_real_,
    price_per_sqft_p99 = if (length(observed_price_per_sqft) > 0L) {
      as.numeric(quantile(observed_price_per_sqft, 0.99, names = FALSE))
    } else NA_real_,
    price_per_sqft_min = if (length(observed_price_per_sqft) > 0L) {
      min(observed_price_per_sqft)
    } else NA_real_,
    price_per_sqft_max = if (length(observed_price_per_sqft) > 0L) {
      max(observed_price_per_sqft)
    } else NA_real_
  )
}, by = .(sale_year, property_type)]
setorder(summary, property_type, sale_year)

observed <- sales_with_size[is.finite(price_per_sqft_total)]
setorder(observed, property_type, price_per_sqft_total, row_id)
lowest <- observed[, head(.SD, 100L), by = property_type]
lowest[, tail := "lowest_100"]
highest <- observed[, tail(.SD, 100L), by = property_type]
highest[, tail := "highest_100"]
extremes <- rbindlist(list(lowest, highest), use.names = TRUE, fill = TRUE)
setorder(extremes, property_type, tail, price_per_sqft_total, row_id)
extreme_columns <- c(
  "tail", "row_id", "sale_document_num", "pin", "parking_pin", "sale_date",
  "sale_year", "property_class", "property_type", "sale_sample_rule",
  "num_parcels_sale", "includes_deeded_parking_pin", "sale_price_nominal",
  "sale_price_prorated_nominal", "square_feet", "square_feet_source",
  "price_per_sqft_total", "price_per_sqft_prorated"
)

temporary_summary <- paste0(summary_file, ".tmp")
temporary_extremes <- paste0(extremes_file, ".tmp")
fwrite(summary, temporary_summary)
fwrite(extremes[, ..extreme_columns], temporary_extremes)
if (!file.rename(temporary_summary, summary_file) ||
    !file.rename(temporary_extremes, extremes_file)) {
  stop("Could not move completed price-per-square-foot tables into place.", call. = FALSE)
}

plot_data <- summary[is.finite(price_per_sqft_p50)]
png(plot_file, width = 1800, height = 1000, res = 180)
par(mar = c(5, 5, 2, 1), las = 1)
plot(
  range(plot_data$sale_year),
  range(c(plot_data$price_per_sqft_p01, plot_data$price_per_sqft_p99)),
  type = "n",
  xlab = "Sale year",
  ylab = "Nominal dollars per square foot",
  main = "Chicago home-sale price per square foot"
)
plot_colors <- c(
  house_or_small_residential = "#2166ac",
  condominium = "#b2182b"
)
for (type_value in names(plot_colors)) {
  type_data <- plot_data[property_type == type_value]
  polygon(
    c(type_data$sale_year, rev(type_data$sale_year)),
    c(type_data$price_per_sqft_p01, rev(type_data$price_per_sqft_p99)),
    col = adjustcolor(plot_colors[type_value], alpha.f = 0.12),
    border = NA
  )
  lines(
    type_data$sale_year,
    type_data$price_per_sqft_p50,
    col = plot_colors[type_value],
    lwd = 3
  )
}
legend(
  "topleft",
  legend = c("House or small residential", "Condominium", "1st--99th percentile"),
  col = c(plot_colors, "grey60"),
  lwd = c(3, 3, 8),
  bty = "n"
)
dev.off()

cat(sprintf("Wrote annual price-per-square-foot summary to %s.\n", summary_file))
cat(sprintf("Wrote extreme observations to %s.\n", extremes_file))
cat(sprintf("Wrote price-per-square-foot plot to %s.\n", plot_file))
