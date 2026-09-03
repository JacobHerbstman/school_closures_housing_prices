suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Usage: Rscript download_historical_sale_coordinates.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}
if (!requireNamespace("curl", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The curl and jsonlite R packages are required.", call. = FALSE)
}

output_file <- sprintf("../output/historical_sale_coordinates_%d_%d.csv", start_year, end_year)

sales <- fread(
  "../input/master_home_transactions_2006_2025.csv",
  select = c("row_id", "pin", "sale_year"),
  colClasses = list(character = c("row_id", "pin"))
)
if (nrow(sales) == 0L || anyDuplicated(sales$row_id) > 0L) {
  stop("Master transactions must contain records uniquely keyed by row_id.", call. = FALSE)
}
if (any(nchar(sales$pin) != 14L) || anyNA(sales$sale_year)) {
  stop("Master transactions contain an invalid PIN or sale year.", call. = FALSE)
}
sales <- sales[sale_year %between% c(start_year, end_year)]
stopifnot(nrow(sales) > 0L)

sale_keys <- unique(sales[, .(pin, sale_year)])
setorder(sale_keys, sale_year, pin)
cat(sprintf(
  "Requesting historical coordinates for %s unique PIN-years.\n",
  format(nrow(sale_keys), big.mark = ",")
))

base_url <- "https://datacatalog.cookcountyil.gov/resource/nj4t-kc8j.json"
request_plan <- list()

for (year_value in sort(unique(sale_keys$sale_year))) {
  year_pins <- sale_keys[sale_year == year_value, pin]
  pin_chunks <- split(year_pins, ceiling(seq_along(year_pins) / 500L))

  for (chunk_number in seq_along(pin_chunks)) {
    parameters <- c(
      "$select" = "pin,year,lon,lat,x_3435,y_3435",
      "$where" = sprintf(
        "year=%d and pin in(%s)",
        year_value,
        paste(sprintf("'%s'", pin_chunks[[chunk_number]]), collapse = ",")
      ),
      "$order" = "pin,year",
      "$limit" = "50000"
    )
    request_plan[[length(request_plan) + 1L]] <- data.table(
      sale_year = year_value,
      chunk_number = chunk_number,
      query = paste0(
        base_url,
        "?",
        paste(
          paste0(
            URLencode(names(parameters), reserved = TRUE),
            "=",
            URLencode(unname(parameters), reserved = TRUE)
          ),
          collapse = "&"
        )
      ),
      destination = tempfile(
        pattern = sprintf("coordinates_%d_%04d_", year_value, chunk_number),
        tmpdir = "../temp",
        fileext = ".json"
      )
    )
  }
}

request_plan <- rbindlist(request_plan)
downloaded <- rep(FALSE, nrow(request_plan))

for (batch_start in seq(1L, nrow(request_plan), by = 12L)) {
  batch <- batch_start:min(batch_start + 11L, nrow(request_plan))

  for (attempt in 1:5) {
    pending <- batch[!downloaded[batch]]
    if (length(pending) == 0L) {
      break
    }
    results <- curl::multi_download(
      request_plan$query[pending],
      request_plan$destination[pending],
      progress = FALSE,
      connecttimeout = 30,
      timeout = 120
    )
    downloaded[pending] <- results$success & results$status_code == 200L
    if (any(!downloaded[batch])) {
      Sys.sleep(2^attempt)
    }
  }
  cat(sprintf(
    "  Downloaded %s of %s requests.\n",
    format(sum(downloaded), big.mark = ","),
    format(length(downloaded), big.mark = ",")
  ))
}

if (any(!downloaded)) {
  failed_requests <- request_plan[!downloaded, sprintf("%d/%d", sale_year, chunk_number)]
  stop(
    sprintf(
      "Historical parcel download failed for %d requests, including %s.",
      length(failed_requests),
      paste(head(failed_requests, 5L), collapse = ", ")
    ),
    call. = FALSE
  )
}

records <- lapply(request_plan$destination, function(path) {
  jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
})
unlink(request_plan$destination)
records <- Filter(function(record) is.data.frame(record) && nrow(record) > 0L, records)
if (length(records) == 0L) {
  stop("Historical parcel requests returned no records.", call. = FALSE)
}

coordinates <- rbindlist(records, use.names = TRUE, fill = TRUE)
expected_columns <- c("pin", "year", "lon", "lat", "x_3435", "y_3435")
missing_columns <- setdiff(expected_columns, names(coordinates))
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Coordinate responses are missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

coordinates[, `:=`(
  pin = as.character(pin),
  sale_year = suppressWarnings(as.integer(year)),
  longitude = suppressWarnings(as.numeric(lon)),
  latitude = suppressWarnings(as.numeric(lat)),
  centroid_x_crs_3435 = suppressWarnings(as.numeric(x_3435)),
  centroid_y_crs_3435 = suppressWarnings(as.numeric(y_3435))
)]
coordinates[, c("year", "lon", "lat", "x_3435", "y_3435") := NULL]
coordinates[, coordinate_record_found := TRUE]

if (anyDuplicated(coordinates[, .(pin, sale_year)]) > 0L) {
  stop("Historical parcel responses are not unique by PIN and year.", call. = FALSE)
}
unexpected_keys <- coordinates[!sale_keys, on = .(pin, sale_year)]
if (nrow(unexpected_keys) > 0L) {
  stop("Historical parcel responses include PIN-years that were not requested.", call. = FALSE)
}

coordinates <- coordinates[sale_keys, on = .(pin, sale_year)]
missing_records <- coordinates[is.na(coordinate_record_found)]
if (nrow(missing_records) > 0L) {
  examples <- missing_records[1:min(.N, 8L), sprintf("%s/%d", pin, sale_year)]
  stop(
    sprintf(
      "Historical parcel data omit %s requested PIN-years, including %s.",
      format(nrow(missing_records), big.mark = ","),
      paste(examples, collapse = ", ")
    ),
    call. = FALSE
  )
}
coordinates[, has_historical_coordinates :=
  is.finite(longitude) & is.finite(latitude) &
    is.finite(centroid_x_crs_3435) & is.finite(centroid_y_crs_3435)]
coordinates[, coordinate_record_found := NULL]

if (any(!coordinates[has_historical_coordinates == TRUE, longitude] %between% c(-88.2, -87.3)) ||
    any(!coordinates[has_historical_coordinates == TRUE, latitude] %between% c(41.4, 42.2))) {
  stop("Historical parcel responses contain coordinates outside the Chicago region.", call. = FALSE)
}

setorder(coordinates, sale_year, pin)
temporary_output <- paste0(output_file, ".tmp")
fwrite(coordinates, temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the completed coordinate file into place.", call. = FALSE)
}
cat(sprintf(
  "Historical coordinates are complete for %s of %s PIN-years.\n",
  format(sum(coordinates$has_historical_coordinates), big.mark = ","),
  format(nrow(coordinates), big.mark = ",")
))
cat(sprintf("Wrote %s PIN-year coordinate records to %s.\n", nrow(coordinates), output_file))
