suppressPackageStartupMessages(library(data.table))

transactions <- fread("../input/corrected_home_sale_characteristics_2006_2025.csv",
                      colClasses = list(character = c("row_id", "pin", "sale_document_num")))
exemptions <- as.data.table(arrow::read_parquet("../input/hie_data.parquet"))
exemptions[, `:=`(start_year = as.integer(year), last_active_year = as.integer(hie_last_year_active))]

# Review every HIE-eligible sale with a family/mixed-use change or a conflict,
# not a hand-picked list of parcels. Later records are validation evidence only.
transactions[, original_group := fcase(
  original_res_class %in% c(202:210, 234, 278, 295), "single_family",
  original_res_class %in% 211L, "two_to_six_units",
  original_res_class %in% 212L, "mixed_use", default = "other_or_missing"
)]
transactions[, corrected_group := fcase(
  res_class %in% c(202:210, 234, 278, 295), "single_family",
  res_class %in% 211L, "two_to_six_units",
  res_class %in% 212L, "mixed_use", default = "other_or_missing"
)]
review <- transactions[hie_correction_eligible == TRUE &
                         (original_group != corrected_group | property_type_conflict),
                       .(row_id, pin, sale_year, original_group, corrected_group,
                         property_type_conflict, res_class, res_char_apts, res_char_use)]
# One reviewed sale may link to several active exemptions. The check year is
# the first year after the last one expires, never used to set sale-year values.
active <- merge(review[, .(row_id, pin, sale_year)],
                exemptions[, .(pin, start_year, last_active_year)],
                by = "pin", allow.cartesian = TRUE, sort = FALSE)
expiry <- active[start_year <= sale_year & last_active_year >= sale_year,
                 .(check_year = max(last_active_year) + 1L), by = row_id]
stopifnot(!anyDuplicated(review$row_id), !anyDuplicated(expiry$row_id), setequal(review$row_id, expiry$row_id))
review[expiry, on = "row_id", check_year := i.check_year]
keys <- unique(review[, .(pin, check_year)])
setorder(keys, pin, check_year)
responses <- list()
queries <- character()
for (first in seq.int(1L, nrow(keys), by = 40L)) {
  batch <- keys[first:min(first + 39L, nrow(keys))]
  parameters <- c(
    "$select" = "pin,year,card,pin_is_multicard,pin_num_cards,class,char_apts,char_use",
    "$where" = paste(sprintf("(pin='%s' and year=%d)", batch$pin, batch$check_year), collapse = " or "),
    "$order" = "pin,year,card", "$limit" = "50000"
  )
  query <- paste0("https://datacatalog.cookcountyil.gov/resource/x54s-btds.json?",
                  paste(paste0(URLencode(names(parameters), reserved = TRUE), "=",
                               URLencode(unname(parameters), reserved = TRUE)), collapse = "&"))
  response <- curl::curl_fetch_memory(query, handle = curl::new_handle(timeout = 60))
  stopifnot(response$status_code == 200L)
  rows <- jsonlite::fromJSON(rawToChar(response$content))
  stopifnot(length(rows) == 0L || (is.data.frame(rows) && nrow(rows) < 50000L))
  responses[[length(responses) + 1L]] <- rows
  queries <- c(queries, query)
  cat(sprintf("Checked %s of %s post-expiry PIN-years.\n", min(first + 39L, nrow(keys)), nrow(keys)))
}
records <- rbindlist(responses, fill = TRUE)
stopifnot(all(c("pin", "year", "card", "class", "char_apts", "char_use") %in% names(records)))
records[, `:=`(year = as.integer(year), card = as.integer(as.numeric(card)), class = as.integer(class))]
stopifnot(!anyNA(records[, .(pin, year, card)]), !anyDuplicated(records[, .(pin, year, card)]),
          nrow(records[!keys, on = .(pin, year = check_year)]) == 0L)
saveRDS(list(review = review, records = records, queries = queries,
             retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), "../output/class_followups.rds")
