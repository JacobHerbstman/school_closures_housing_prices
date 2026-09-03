suppressPackageStartupMessages(library(data.table))

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop(
    "Usage: Rscript download_residential_improvements.R START_YEAR END_YEAR",
    call. = FALSE
  )
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}
if (!requireNamespace("curl", quietly = TRUE) ||
    !requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The curl and jsonlite R packages are required.", call. = FALSE)
}

output_file <- sprintf(
  "../output/residential_improvements_%d_%d.csv",
  start_year,
  end_year
)
stale_downloads <- list.files(
  "../temp",
  pattern = "^improvements_.*\\.json$",
  full.names = TRUE
)
unlink(stale_downloads)

master_transactions <- fread(
  sprintf(
    "../input/master_home_transactions_%d_%d.csv",
    start_year,
    end_year
  ),
  select = c("pin", "sale_year"),
  colClasses = list(character = "pin")
)
residential_keys <- unique(master_transactions[
  sale_year %between% c(start_year, end_year),
  .(pin, year = sale_year)
])
if (nrow(residential_keys) == 0L || any(nchar(residential_keys$pin) != 14L)) {
  stop("The master transactions contain no valid residential PIN-years.", call. = FALSE)
}
setorder(residential_keys, year, pin)

cat(sprintf(
  "Requesting improvements for %s residential sale PIN-years.\n",
  format(nrow(residential_keys), big.mark = ",")
))

source_columns <- c(
  "pin", "year", "card", "class", "township_code", "tieback_key_pin",
  "tieback_proration_rate", "card_proration_rate", "cdu",
  "pin_is_multicard", "pin_num_cards", "pin_is_multiland",
  "pin_num_landlines", "char_yrblt", "char_bldg_sf", "char_land_sf",
  "char_beds", "char_rooms", "char_fbath", "char_hbath", "char_frpl",
  "char_type_resd", "char_cnst_qlty", "char_apts", "char_attic_fnsh",
  "char_gar1_att", "char_gar1_area", "char_gar1_size", "char_gar1_cnst",
  "char_attic_type", "char_bsmt", "char_ext_wall", "char_heat",
  "char_repair_cnd", "char_bsmt_fin", "char_roof_cnst", "char_use",
  "char_site", "char_ncu", "char_renovation", "char_porch", "char_air",
  "char_tp_plan"
)

base_url <- "https://datacatalog.cookcountyil.gov/resource/x54s-btds.json"
request_plan <- list()

for (year_value in sort(unique(residential_keys$year))) {
  year_pins <- residential_keys[year == year_value, pin]
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
  if (any(!downloaded[batch])) {
    stop(
      sprintf(
        "Residential-improvement batch beginning with request %d failed after five attempts.",
        batch_start
      ),
      call. = FALSE
    )
  }
}

if (any(!downloaded)) {
  failed_requests <- request_plan[
    !downloaded,
    sprintf("%d/%d", year, chunk_number)
  ]
  stop(
    sprintf(
      "Residential-improvement download failed for %d requests, including %s.",
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
  stop("Residential-improvement requests returned no records.", call. = FALSE)
}

improvements <- rbindlist(records, use.names = TRUE, fill = TRUE)
missing_columns <- setdiff(source_columns, names(improvements))
if (length(missing_columns) > 0L) {
  stop(
    sprintf(
      "Residential-improvement responses are missing: %s",
      paste(missing_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}

improvements[, `:=`(
  pin = as.character(pin),
  year = suppressWarnings(as.integer(year)),
  card = suppressWarnings(as.integer(card)),
  class = suppressWarnings(as.integer(class))
)]
if (any(nchar(improvements$pin) != 14L) ||
    anyNA(improvements[, .(year, card)])) {
  stop("Residential-improvement responses contain an invalid key.", call. = FALSE)
}
if (anyDuplicated(improvements[, .(pin, year, card)]) > 0L) {
  stop("Residential improvements are not unique by PIN, year, and card.", call. = FALSE)
}
if (nrow(improvements[!residential_keys, on = .(pin, year)]) > 0L) {
  stop("Residential-improvement responses include an unrequested PIN-year.", call. = FALSE)
}

returned_keys <- unique(improvements[, .(pin, year)])
matched_keys <- returned_keys[residential_keys, on = .(pin, year), nomatch = 0L, .N]
cat(sprintf(
  "Improvement records found for %s of %s requested PIN-years (%.2f percent).\n",
  format(matched_keys, big.mark = ","),
  format(nrow(residential_keys), big.mark = ","),
  100 * matched_keys / nrow(residential_keys)
))
cat(sprintf(
  "%s returned PIN-years have more than one improvement card.\n",
  format(improvements[, .(cards = .N), by = .(pin, year)][cards > 1L, .N], big.mark = ",")
))

setorder(improvements, year, pin, card)
setcolorder(improvements, source_columns)

fwrite(improvements, output_file)
cat(sprintf(
  "Wrote %s PIN-year-card records.\n",
  format(nrow(improvements), big.mark = ",")
))
