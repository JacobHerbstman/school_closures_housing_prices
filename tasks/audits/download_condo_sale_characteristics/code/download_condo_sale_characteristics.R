suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop(
    "Usage: Rscript download_condo_sale_characteristics.R START_YEAR END_YEAR",
    call. = FALSE
  )
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}
if (!requireNamespace("curl", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The curl and jsonlite R packages are required.", call. = FALSE)
}

input_file <- sprintf("../input/parcel_sales_%d_%d.csv", start_year, end_year)
output_file <- sprintf(
  "../output/condo_sale_characteristics_%d_%d.csv",
  start_year,
  end_year
)
temporary_output <- paste0(output_file, ".tmp")
stale_downloads <- list.files(
  "../temp",
  pattern = "^condos_.*\\.json$",
  full.names = TRUE
)
unlink(c(temporary_output, stale_downloads))

sales <- fread(
  input_file,
  select = c("pin", "year", "class"),
  colClasses = list(character = "pin")
)
sales[, `:=`(
  year = suppressWarnings(as.integer(year)),
  property_class = suppressWarnings(as.integer(class))
)]

condo_keys <- unique(
  sales[
    year %between% c(start_year, end_year) & property_class == 299L,
    .(pin, year)
  ]
)
condo_keys[, pin := gsub("[^0-9]", "", trimws(pin))]
condo_keys[nchar(pin) == 13L, pin := paste0("0", pin)]
if (nrow(condo_keys) == 0L || any(nchar(condo_keys$pin) != 14L)) {
  stop("Parcel sales contain no valid condominium PIN-years.", call. = FALSE)
}
setorder(condo_keys, year, pin)

cat(sprintf(
  "Requesting characteristics for %s condominium PIN-years.\n",
  format(nrow(condo_keys), big.mark = ",")
))

source_columns <- c(
  "pin", "pin10", "year", "card", "class", "township_code",
  "tieback_key_pin", "tieback_proration_rate", "card_proration_rate",
  "char_yrblt", "char_building_sf", "char_unit_sf", "char_bedrooms",
  "char_full_baths", "char_half_baths", "char_building_non_units",
  "char_building_pins", "char_land_sf", "cdu", "pin_is_multiland",
  "pin_num_landlines", "bldg_is_mixed_use", "is_parking_space",
  "is_common_area"
)

base_url <- "https://datacatalog.cookcountyil.gov/resource/3r7i-mrz4.json"
request_plan <- list()

for (year_value in sort(unique(condo_keys$year))) {
  year_pins <- condo_keys[year == year_value, pin]
  pin_chunks <- split(year_pins, ceiling(seq_along(year_pins) / 500L))

  for (chunk_number in seq_along(pin_chunks)) {
    parameters <- c(
      "$select" = paste(source_columns, collapse = ","),
      "$where" = sprintf(
        "year=%d and pin in(%s)",
        year_value,
        paste(sprintf("'%s'", pin_chunks[[chunk_number]]), collapse = ",")
      ),
      "$order" = "pin,year,card",
      "$limit" = "50000"
    )
    request_plan[[length(request_plan) + 1L]] <- data.table(
      year = year_value,
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
        pattern = sprintf("condos_%d_%04d_", year_value, chunk_number),
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
  if (any(!downloaded[batch])) {
    stop(
      sprintf(
        "Condo-characteristics batch beginning with request %d failed after five attempts.",
        batch_start
      ),
      call. = FALSE
    )
  }
}

if (any(!downloaded)) {
  failed_requests <- request_plan[!downloaded, sprintf("%d/%d", year, chunk_number)]
  stop(
    sprintf(
      "Condo-characteristics download failed for %d requests, including %s.",
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
  stop("Condo-characteristics requests returned no records.", call. = FALSE)
}

characteristics <- rbindlist(records, use.names = TRUE, fill = TRUE)
missing_columns <- setdiff(source_columns, names(characteristics))
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Condo responses are missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

parse_optional_boolean <- function(values, column_name) {
  normalized <- tolower(trimws(as.character(values)))
  normalized[normalized == ""] <- NA_character_
  invalid <- !is.na(normalized) & !normalized %in% c("true", "false")
  if (any(invalid)) {
    stop(
      sprintf("%s contains a value other than true, false, or missing.", column_name),
      call. = FALSE
    )
  }
  normalized == "true"
}

characteristics[, `:=`(
  pin = as.character(pin),
  pin10 = as.character(pin10),
  year = suppressWarnings(as.integer(year)),
  card = suppressWarnings(as.integer(card)),
  property_class = suppressWarnings(as.integer(class)),
  tieback_proration_rate = suppressWarnings(as.numeric(tieback_proration_rate)),
  card_proration_rate = suppressWarnings(as.numeric(card_proration_rate)),
  condo_year_built = suppressWarnings(as.integer(char_yrblt)),
  condo_building_sqft = suppressWarnings(as.numeric(char_building_sf)),
  condo_unit_sqft = suppressWarnings(as.numeric(char_unit_sf)),
  condo_bedrooms = suppressWarnings(as.numeric(char_bedrooms)),
  condo_full_baths = suppressWarnings(as.numeric(char_full_baths)),
  condo_half_baths = suppressWarnings(as.numeric(char_half_baths)),
  condo_building_non_units = suppressWarnings(as.integer(char_building_non_units)),
  condo_building_pins = suppressWarnings(as.integer(char_building_pins)),
  condo_land_sqft = suppressWarnings(as.numeric(char_land_sf)),
  pin_is_multiland = parse_optional_boolean(pin_is_multiland, "pin_is_multiland"),
  pin_num_landlines = suppressWarnings(as.integer(pin_num_landlines)),
  condo_building_is_mixed_use = parse_optional_boolean(
    bldg_is_mixed_use,
    "bldg_is_mixed_use"
  ),
  is_parking_space = parse_optional_boolean(is_parking_space, "is_parking_space"),
  is_common_area = parse_optional_boolean(is_common_area, "is_common_area")
)]
characteristics[, c(
  "class", "char_yrblt", "char_building_sf", "char_unit_sf",
  "char_bedrooms", "char_full_baths", "char_half_baths",
  "char_building_non_units", "char_building_pins", "char_land_sf",
  "bldg_is_mixed_use"
) := NULL]

if (any(nchar(characteristics$pin) != 14L) ||
    any(nchar(characteristics$pin10) != 10L) ||
    anyNA(characteristics$year)) {
  stop("Condo responses contain an invalid full PIN.", call. = FALSE)
}
if (anyDuplicated(characteristics[, .(pin, year)]) > 0L) {
  stop("Condo responses are not unique by PIN and year.", call. = FALSE)
}
unexpected_keys <- characteristics[!condo_keys, on = .(pin, year)]
if (nrow(unexpected_keys) > 0L) {
  stop("Condo responses include PIN-years that were not requested.", call. = FALSE)
}

matched_keys <- characteristics[condo_keys, on = .(pin, year), nomatch = 0L, .N]
cat(sprintf(
  "Characteristics found for %s of %s requested condominium PIN-years (%.2f percent).\n",
  format(matched_keys, big.mark = ","),
  format(nrow(condo_keys), big.mark = ","),
  100 * matched_keys / nrow(condo_keys)
))

setorder(characteristics, year, pin)
setcolorder(characteristics, c(
  "pin", "pin10", "year", "card", "property_class", "township_code",
  "tieback_key_pin", "tieback_proration_rate", "card_proration_rate", "cdu",
  "pin_is_multiland", "pin_num_landlines", "is_parking_space",
  "is_common_area", "condo_year_built", "condo_building_sqft",
  "condo_unit_sqft", "condo_bedrooms", "condo_full_baths",
  "condo_half_baths", "condo_building_non_units", "condo_building_pins",
  "condo_land_sqft", "condo_building_is_mixed_use"
))

fwrite(characteristics, temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the completed condo-characteristics file into place.", call. = FALSE)
}
cat(sprintf(
  "Wrote %s condominium PIN-year records to %s.\n",
  format(nrow(characteristics), big.mark = ","),
  output_file
))
