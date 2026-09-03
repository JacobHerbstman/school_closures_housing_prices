suppressPackageStartupMessages(library(data.table))

audit <- readRDS("../output/careful_characteristic_updates.rds")
reference <- readRDS("../output/characteristic_updates.rds")$transactions
transactions <- audit$transactions

# Review all repeated-entry sales and unresolved room/bed counts, plus the
# twelve largest original additions (one sale per PIN). No parcel exceptions.
largest <- reference[hie_correction_eligible == TRUE,
                     .(row_id, pin, sale_year, addition = hie_res_char_bldg_sf - res_char_bldg_sf)]
setorder(largest, -addition, sale_year, row_id, na.last = TRUE)
largest <- head(largest[!duplicated(pin)], 12L)
review_ids <- transactions[hie_repeated_exemption_records > 0 | hie_rooms_beds_unresolved |
                            row_id %in% largest$row_id, row_id]
review <- audit$source_membership[row_id %in% review_ids,
                                 .(check_year = max(last_active_year) + 1L), by = .(row_id, pin)]
keys <- unique(review[, .(pin, check_year)])
setorder(keys, pin, check_year)
stopifnot(nrow(keys) > 0L, !anyDuplicated(review$row_id),
          all(grepl("^[0-9]{14}$", keys$pin)))

responses <- list()
queries <- character()
for (first in seq.int(1L, nrow(keys), by = 40L)) {
  batch <- keys[first:min(first + 39L, nrow(keys))]
  parameters <- c(
    "$select" = "pin,year,card,pin_is_multicard,pin_num_cards,char_bldg_sf,char_rooms,char_beds",
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
}
records <- rbindlist(responses, fill = TRUE)
stopifnot(all(c("pin", "year", "card", "char_bldg_sf", "char_rooms", "char_beds") %in% names(records)))
records[, `:=`(year = as.integer(year), card = as.integer(as.numeric(card)))]
stopifnot(!anyNA(records[, .(pin, year, card)]),
          !anyDuplicated(records[, .(pin, year, card)]),
          nrow(records[!keys, on = .(pin, year = check_year)]) == 0L)
saveRDS(list(review = review, records = records, queries = queries,
             retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE)),
        "../output/post_expiry_records.rds")
cat(sprintf("Requested %s post-expiry PIN-years for %s sales; returned %s card records.\n",
            nrow(keys), nrow(review), nrow(records)))
