suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript build_geocoded_home_sales.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

sales_file <- sprintf("../input/home_sales_%d_%d.csv", start_year, end_year)
output_file <- sprintf("../output/geocoded_home_sales_%d_%d.csv", start_year, end_year)

sales <- fread(
  sales_file,
  colClasses = list(character = c("row_id", "pin", "sale_document_num"))
)
coordinates <- fread(
  "../input/historical_sale_coordinates_2006_2025.csv",
  colClasses = list(character = "pin")
)

if (nrow(sales) == 0L || anyDuplicated(sales$row_id) > 0L) {
  stop("Home sales must contain records uniquely keyed by row_id.", call. = FALSE)
}
if (anyDuplicated(coordinates[, .(pin, sale_year)]) > 0L) {
  stop("Historical coordinates must be unique by PIN and sale year.", call. = FALSE)
}

setkey(coordinates, pin, sale_year)
geocoded_sales <- coordinates[sales, on = .(pin, sale_year)]
if (nrow(geocoded_sales) != nrow(sales)) {
  stop("The coordinate join changed the number of sale records.", call. = FALSE)
}
if (!identical(geocoded_sales$row_id, sales$row_id) || anyDuplicated(geocoded_sales$row_id) > 0L) {
  stop("The coordinate join changed row_id identity or order.", call. = FALSE)
}

if (anyNA(geocoded_sales$has_historical_coordinates)) {
  stop("A cleaned sale PIN-year is absent from the coordinate input.", call. = FALSE)
}

coordinate_fields_complete <-
  is.finite(geocoded_sales$longitude) &
  is.finite(geocoded_sales$latitude) &
  is.finite(geocoded_sales$centroid_x_crs_3435) &
  is.finite(geocoded_sales$centroid_y_crs_3435)
if (any(geocoded_sales$has_historical_coordinates != coordinate_fields_complete)) {
  stop("The coordinate availability flag disagrees with the coordinate fields.", call. = FALSE)
}
invalid_coordinates <- geocoded_sales[coordinate_fields_complete == FALSE]
coordinate_coverage <- mean(geocoded_sales$has_historical_coordinates)
if (coordinate_coverage < 0.999) {
  stop(
    sprintf("Only %.3f percent of cleaned sales have historical coordinates.", 100 * coordinate_coverage),
    call. = FALSE
  )
}

cat(sprintf(
  "Historical coordinates are complete for %s of %s sales (%.4f percent).\n",
  format(sum(geocoded_sales$has_historical_coordinates), big.mark = ","),
  format(nrow(geocoded_sales), big.mark = ","),
  100 * coordinate_coverage
))
if (nrow(invalid_coordinates) > 0L) {
  cat(sprintf(
    "Excluding %s sales whose historical parcel record has blank coordinates.\n",
    format(nrow(invalid_coordinates), big.mark = ",")
  ))
}
geocoded_sales <- geocoded_sales[has_historical_coordinates == TRUE]

if (any(!geocoded_sales$longitude %between% c(-88.2, -87.3)) ||
    any(!geocoded_sales$latitude %between% c(41.4, 42.2))) {
  stop("A geocoded sale has coordinates outside the Chicago region.", call. = FALSE)
}

geocoded_sales[, has_historical_coordinates := NULL]
geocoded_sales[, coordinate_source := "historical_exact_pin_year"]
setcolorder(
  geocoded_sales,
  c(
    names(sales),
    "longitude", "latitude", "centroid_x_crs_3435", "centroid_y_crs_3435",
    "coordinate_source"
  )
)

fwrite(geocoded_sales, output_file, na = "NA")
cat(sprintf(
  "Retained %s home sales with exact historical PIN-year coordinates.\n",
  format(nrow(geocoded_sales), big.mark = ",")
))
cat(sprintf("Wrote geocoded home sales to %s.\n", output_file))
