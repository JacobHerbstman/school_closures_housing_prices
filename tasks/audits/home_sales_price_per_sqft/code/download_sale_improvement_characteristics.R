suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop(
    "Usage: Rscript download_sale_improvement_characteristics.R START_YEAR END_YEAR",
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

input_file <- sprintf("../input/home_sales_%d_%d.csv", start_year, end_year)
output_file <- sprintf(
  "../output/sale_improvement_characteristics_%d_%d.csv",
  start_year,
  end_year
)

sales <- fread(
  input_file,
  select = c("pin", "sale_year", "property_type"),
  colClasses = list(character = "pin")
)
house_keys <- unique(sales[
  property_type == "house_or_small_residential",
  .(pin, year = sale_year)
])
if (nrow(house_keys) == 0L || any(nchar(house_keys$pin) != 14L)) {
  stop("Clean home sales contain no valid house PIN-years.", call. = FALSE)
}
setorder(house_keys, year, pin)

cat(sprintf(
  "Requesting improvement characteristics for %s house PIN-years.\n",
  format(nrow(house_keys), big.mark = ",")
))

base_url <- "https://datacatalog.cookcountyil.gov/resource/x54s-btds.json"
request_plan <- list()

for (year_value in sort(unique(house_keys$year))) {
  year_pins <- house_keys[year == year_value, pin]
  pin_chunks <- split(year_pins, ceiling(seq_along(year_pins) / 500L))

  for (chunk_number in seq_along(pin_chunks)) {
    parameters <- c(
      "$select" = paste(
        c(
          "pin", "year", "card", "class", "char_bldg_sf",
          "pin_is_multicard", "pin_num_cards"
        ),
        collapse = ","
      ),
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
        pattern = sprintf("improvements_%d_%04d_", year_value, chunk_number),
        tmpdir = "../temp",
        fileext = ".json"
      )
    )
  }
}

request_plan <- rbindlist(request_plan)
downloaded <- rep(FALSE, nrow(request_plan))
on.exit(unlink(request_plan$destination), add = TRUE)

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
  failed_requests <- request_plan[!downloaded, sprintf("%d/%d", year, chunk_number)]
  stop(
    sprintf(
      "Improvement-characteristics download failed for %d requests, including %s.",
      length(failed_requests),
      paste(head(failed_requests, 5L), collapse = ", ")
    ),
    call. = FALSE
  )
}

records <- lapply(request_plan$destination, function(path) {
  jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
})
records <- Filter(function(record) is.data.frame(record) && nrow(record) > 0L, records)
if (length(records) == 0L) {
  stop("Improvement-characteristics requests returned no records.", call. = FALSE)
}

characteristics <- rbindlist(records, use.names = TRUE, fill = TRUE)
required_columns <- c(
  "pin", "year", "card", "class", "char_bldg_sf", "pin_is_multicard",
  "pin_num_cards"
)
missing_columns <- setdiff(required_columns, names(characteristics))
if (length(missing_columns) > 0L) {
  stop(
    sprintf(
      "Improvement responses are missing: %s",
      paste(missing_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}

normalized_multicard <- tolower(trimws(as.character(characteristics$pin_is_multicard)))
normalized_multicard[normalized_multicard == ""] <- NA_character_
if (any(!is.na(normalized_multicard) & !normalized_multicard %in% c("true", "false"))) {
  stop("pin_is_multicard contains a value other than true, false, or missing.", call. = FALSE)
}

characteristics[, `:=`(
  pin = as.character(pin),
  year = suppressWarnings(as.integer(year)),
  card = suppressWarnings(as.integer(card)),
  property_class = suppressWarnings(as.integer(class)),
  building_sqft = suppressWarnings(as.numeric(char_bldg_sf)),
  pin_is_multicard = normalized_multicard == "true",
  pin_num_cards = suppressWarnings(as.integer(pin_num_cards))
)]
characteristics[, c("class", "char_bldg_sf") := NULL]

if (any(nchar(characteristics$pin) != 14L)) {
  stop("Improvement responses contain an invalid full PIN.", call. = FALSE)
}
if (anyDuplicated(characteristics[, .(pin, year, card)]) > 0L) {
  stop("Improvement responses are not unique by PIN, year, and card.", call. = FALSE)
}
unexpected_keys <- characteristics[!house_keys, on = .(pin, year)]
if (nrow(unexpected_keys) > 0L) {
  stop("Improvement responses include PIN-years that were not requested.", call. = FALSE)
}

matched_keys <- unique(characteristics[, .(pin, year)])[house_keys, on = .(pin, year), nomatch = 0L, .N]
cat(sprintf(
  "Improvement records found for %s of %s requested house PIN-years (%.2f percent).\n",
  format(matched_keys, big.mark = ","),
  format(nrow(house_keys), big.mark = ","),
  100 * matched_keys / nrow(house_keys)
))

setorder(characteristics, year, pin, card)
setcolorder(characteristics, c(
  "pin", "year", "card", "property_class", "building_sqft",
  "pin_is_multicard", "pin_num_cards"
))

temporary_output <- paste0(output_file, ".tmp")
fwrite(characteristics, temporary_output)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the completed improvement-characteristics file into place.", call. = FALSE)
}
cat(sprintf(
  "Wrote %s improvement records to %s.\n",
  format(nrow(characteristics), big.mark = ","),
  output_file
))
