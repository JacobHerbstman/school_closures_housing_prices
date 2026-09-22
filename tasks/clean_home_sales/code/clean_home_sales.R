# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/clean_home_sales/code")
# start_year <- 2008
# end_year <- 2018
suppressPackageStartupMessages(library(data.table))
source("../../shared/code/report_data.R")

arguments <- commandArgs(trailingOnly = TRUE)
if (interactive()) arguments <- c(start_year, end_year)
if (length(arguments) != 2L) {
  stop("Usage: Rscript clean_home_sales.R START_YEAR END_YEAR", call. = FALSE)
}

start_year <- suppressWarnings(as.integer(arguments[1]))
end_year <- suppressWarnings(as.integer(arguments[2]))
if (!is.finite(start_year) || !is.finite(end_year) || start_year > end_year) {
  stop("START_YEAR and END_YEAR must define a valid year range.", call. = FALSE)
}

transactions <- fread(
  "../input/corrected_home_sale_characteristics_2006_2025.csv",
  colClasses = list(character = c(
    "row_id", "sale_document_num", "pin", "res_char_apts"
  ))
)
if (nrow(transactions) == 0L || anyDuplicated(transactions$row_id) > 0L) {
  stop("Characterized transactions must be nonempty and unique by row_id.", call. = FALSE)
}

required_columns <- c(
  "pin", "sale_date", "sale_year", "sale_month", "sale_price_nominal", "sale_type",
  "mydec_deed_type",
  "analysis_class", "res_tieback_proration_rate",
  "sale_filter_same_sale_within_365", "sale_filter_less_than_10k",
  "sale_filter_deed_type", "single_improvement_card", "res_char_yrblt",
  "res_char_bldg_sf", "res_char_land_sf", "res_char_beds",
  "res_char_rooms", "res_char_fbath", "res_char_type_resd",
  "res_char_cnst_qlty", "res_char_repair_cnd", "res_char_apts"
)
missing_columns <- setdiff(required_columns, names(transactions))
if (length(missing_columns) > 0L) {
  stop(
    sprintf("Characterized transactions are missing: %s", paste(missing_columns, collapse = ", ")),
    call. = FALSE
  )
}

# A market sale passes the county's three sale-quality flags and is a non-land
# sale above $10,000.
transactions[, market_sale :=
  sale_filter_same_sale_within_365 == FALSE & sale_filter_less_than_10k == FALSE &
    sale_filter_deed_type == FALSE & is.finite(sale_price_nominal) &
    sale_price_nominal > 10000 & !is.na(sale_type) & sale_type != "LAND"]

# Quick resales are often flips: renovation between the two sales is not
# recorded in the assessor characteristics. Flag them for robustness checks
# rather than dropping them. Gaps use every 2006--2025 market sale, including
# foreclosure auctions that leave the price sample below. Most pre-2013 dates
# are known only to the month.
recorded_sales <- transactions[market_sale == TRUE, .(row_id, pin, sale_date)]
setorder(recorded_sales, pin, sale_date, row_id)
recorded_sales[, `:=`(
  days_since_previous_sale = as.integer(sale_date - shift(sale_date)),
  days_until_next_sale = as.integer(shift(sale_date, type = "lead") - sale_date)
), by = pin]
transactions[recorded_sales, on = "row_id", `:=`(
  days_since_previous_sale = i.days_since_previous_sale,
  days_until_next_sale = i.days_until_next_sale
)]
transactions[, resale_within_365 := !is.na(days_since_previous_sale) & days_since_previous_sale <= 365L]

home_sales <- transactions[sale_year %between% c(start_year, end_year)]
cat(sprintf("Transactions in %d--%d: %s\n", start_year, end_year, format(nrow(home_sales), big.mark = ",")))

home_sales <- home_sales[market_sale == TRUE]
home_sales[, market_sale := NULL]
cat(sprintf("Market sales (county flags; non-land above $10,000): %s\n", format(nrow(home_sales), big.mark = ",")))

# Foreclosure auctions and transfers to a lender or land bank are not market
# sales and are removed. REO resales by lenders, servicers, securitization
# trustees, Fannie Mae, Freddie Mac, HUD, the VA or the land bank are market
# sales of distressed homes. Foreclosure incidence may respond to closures, so
# REO resales are flagged (reo_sale), not removed. Party names identify these
# sales in every year. Banks acting as Chicago land trustees convey ordinary
# sales; national banks named as trustees of mortgage securitizations are REO
# sellers. MyDec deed types exist only from 2013, so they classify a sale only
# when its seller name is missing (almost all in 2014--2016): court and officer
# deeds as auctions, deeds in lieu of foreclosure as transfers to a lender, and
# special warranty deeds, mostly REO when the seller is known, as REO.
party_names <- fread(
  "../input/parcel_sales_2006_2025.csv",
  select = c("row_id", "sale_seller_name", "sale_buyer_name"),
  colClasses = list(character = c("row_id", "sale_seller_name", "sale_buyer_name")),
  na.strings = NULL
)
stopifnot(!anyDuplicated(party_names$row_id))
home_sales[party_names, on = "row_id", `:=`(
  sale_seller_name = i.sale_seller_name,
  sale_buyer_name = i.sale_buyer_name
)]
stopifnot(!anyNA(home_sales$sale_seller_name), !anyNA(home_sales$sale_buyer_name))

auction_seller <- "JUDI[A-Z]* +SALE|JUDICIAL CORP|INTER ?COUNTY JUDI|KALLEN R|^JSC$|SHERIFF|SELLING OFFICER|SPECIAL COMMISSIONER"
agency <- "FANNIE|FREDDIE|FEDERAL (NATIONAL|NATL) (MORTGAGE|MTG)|FEDERAL HOM|HOUSING (AND|&) URBAN|SECRETARY OF HOUSING|VETERANS AFFAIRS|SECRETARY OF VETERANS|LAND BANK|COUNTY OF COOK"
lender <- paste0(
  "(^| )(BANK|BK|BANC|MORTGAGE|MTG|FSB|REO)( |,|$)|CITIMORTGAGE|CITIBANK|LOAN SERV|SERVICING|HOMESALES INC|SAVINGS FUND|MTGLQ|PENNYMAC|REVERSE|",
  # Subprime lenders and servicers selling REO under consumer-finance names.
  "LIQUIDATION PROP|HOME LENDERS|LENDING SERV|HOME LOANS?|(^| )LOAN LLC|INV & LOAN|RESIDENTIAL FUNDG|RESIDENTIAL FUNDING|SUTTON FUNDG|BROAD STREET FUNDING|FINANCE OF AMERICA|",
  "(HOUSEHOLD|BENEFICIAL|CONSUMER|HOME|AMERICAN GEN|WELLS FARGO|WILMINGTON|HOMECOMINGS|SELENE) FIN"
)
land_trustee <- "LAND TRUST|TRUST NO|TRUST NUMBER|U/T/A|TRUST AGREEMENT|AS TR|TRUSTEE|(AND|&|&AMP;) TRUST|TR [0-9]"
securitization_trustee <- "DEUTSCHE|U\\.? ?S\\.? (BANK|BK)|WELLS FARGO|NEW YORK|BANK NY|HSBC|CITIBANK|WILMINGTON|CHRISTIANA|POOLING|CERTIFICATE|PASS.THROUGH|ASSET.BACKED"
auction_deeds <- c(
  "Judicial Sale", "Sheriff's Deed", "Selling Officer's Deed", "Special Commissioner's Deed",
  "Judge's Deed", "Court Officer's Deed", "Master's Deed"
)
home_sales[, `:=`(seller = toupper(sale_seller_name), buyer = toupper(sale_buyer_name))]
home_sales[, `:=`(
  lender_seller = grepl(agency, seller) |
    (grepl(lender, seller) & (!grepl(land_trustee, seller) | grepl(securitization_trustee, seller))),
  lender_buyer = grepl(agency, buyer) |
    (grepl(lender, buyer) & (!grepl(land_trustee, buyer) | grepl(securitization_trustee, buyer))),
  seller_missing = !grepl("[A-Z]", gsub("UNKNOWN|N/A", "", seller)),
  buyer_missing = !grepl("[A-Z]", gsub("UNKNOWN|N/A", "", buyer))
)]
home_sales[, `:=`(
  foreclosure_auction = grepl(auction_seller, seller) |
    (seller_missing & mydec_deed_type %chin% auction_deeds),
  transfer_to_lender = lender_buyer |
    (seller_missing & mydec_deed_type == "Deed in lieu of Foreclosure"),
  reo_sale = lender_seller | (seller_missing & mydec_deed_type == "Special Warranty Deed")
)]
# Identical buyer and seller names suggest a related-party transfer, whose
# price need not be a market price. Land trustees appear on both sides of
# ordinary sales, so they do not count. Flagged, not removed.
home_sales[, same_party_names := !seller_missing & !buyer_missing & !grepl(land_trustee, seller) &
  gsub("[^A-Z0-9]", "", seller) == gsub("[^A-Z0-9]", "", buyer)]
cat("Foreclosure auctions and transfers to lenders (removed); REO resales (flagged):\n")
print(home_sales[, .(sales = .N, auctions = sum(foreclosure_auction),
                     to_lender = sum(transfer_to_lender & !foreclosure_auction),
                     reo_retained = sum(reo_sale & !foreclosure_auction & !transfer_to_lender)),
                 by = sale_year][order(sale_year)])
home_sales <- home_sales[foreclosure_auction == FALSE & transfer_to_lender == FALSE]
home_sales[, c("seller", "buyer", "lender_seller", "lender_buyer", "seller_missing", "buyer_missing",
               "foreclosure_auction", "transfer_to_lender") := NULL]
cat(sprintf("Excluding foreclosure auctions and transfers to lenders: %s\n", format(nrow(home_sales), big.mark = ",")))

# The characteristics must describe what was sold: one building card, wholly on
# this parcel (a tieback proration below 1 splits one building across parcels).
home_sales <- home_sales[
  single_improvement_card == TRUE & analysis_class %in% c(202:211, 234, 278, 295) &
    res_tieback_proration_rate == 1
]
cat(sprintf(
  "Single-card, unsplit, non-mixed-use residential sales: %s\n",
  format(nrow(home_sales), big.mark = ",")
))

# Hedonic controls must be observed. The one exception is the unit count of a
# two-to-six-unit building (below).
home_sales <- home_sales[
  is.finite(res_char_yrblt) & is.finite(res_char_bldg_sf) & res_char_bldg_sf > 0 &
    is.finite(res_char_land_sf) & res_char_land_sf > 0 & is.finite(res_char_beds) &
    is.finite(res_char_rooms) & is.finite(res_char_fbath) &
    !is.na(res_char_type_resd) & nzchar(trimws(res_char_type_resd)) &
    !is.na(res_char_cnst_qlty) & nzchar(trimws(res_char_cnst_qlty)) &
    !is.na(res_char_repair_cnd) & nzchar(trimws(res_char_repair_cnd))
]

# Class 211 is a 2-6-unit building. A blank unit count is kept as unknown
# (apartment_count NA): blanks are concentrated in Lake township and decline
# over time, so requiring a count would drop cheaper buildings unevenly.
home_sales[, apartment_count := fcase(
  res_char_apts == "Two", 2L,
  res_char_apts == "Three", 3L,
  res_char_apts == "Four", 4L,
  res_char_apts == "Five", 5L,
  res_char_apts == "Six", 6L,
  default = NA_integer_
)]
cat(sprintf(
  "Complete core hedonics: %s (%s class-211 sales with unknown unit count)\n",
  format(nrow(home_sales), big.mark = ","),
  format(home_sales[analysis_class == 211L & is.na(apartment_count), .N], big.mark = ",")
))

# Fewer rooms than bedrooms, or more than $5,000 per building square foot, is a
# recording error.
home_sales[, price_per_building_sqft := sale_price_nominal / res_char_bldg_sf]
cat(sprintf(
  "Excluding %s records with fewer rooms than bedrooms and %s above $5,000 per square foot.\n",
  format(home_sales[res_char_rooms < res_char_beds, .N], big.mark = ","),
  format(home_sales[price_per_building_sqft > 5000, .N], big.mark = ",")
))
home_sales <- home_sales[res_char_rooms >= res_char_beds & price_per_building_sqft <= 5000]
stopifnot(nrow(home_sales) > 0L, !anyDuplicated(home_sales$row_id),
          all(home_sales$res_char_yrblt <= home_sales$sale_year),
          all(home_sales$res_char_beds >= 0), all(home_sales$res_char_fbath >= 0))

# Flag, do not trim, sales outside the within-year citywide 1st-99th
# percentiles of nominal price, the conventional trimming robustness check.
home_sales[, price_outside_p01_p99 :=
  sale_price_nominal < quantile(sale_price_nominal, 0.01, type = 7) |
    sale_price_nominal > quantile(sale_price_nominal, 0.99, type = 7),
  by = sale_year]
cat(sprintf("Outside within-year 1st-99th price percentiles (flagged, retained): %s\n",
            format(sum(home_sales$price_outside_p01_p99), big.mark = ",")))
cat(sprintf("Flagged, retained: %s REO resales, %s resales within 365 days, %s identical party names, of %s\n",
            format(sum(home_sales$reo_sale), big.mark = ","),
            format(sum(home_sales$resale_within_365), big.mark = ","),
            format(sum(home_sales$same_party_names), big.mark = ","), format(nrow(home_sales), big.mark = ",")))

cpi <- fread("../input/chicago_cpi_all_items.csv")
if (!all(c("observation_date", "chicago_cpi_all_items") %in% names(cpi))) {
  stop("Chicago CPI input is missing required columns.", call. = FALSE)
}
cpi[, `:=`(
  sale_year = as.integer(substr(observation_date, 1L, 4L)),
  sale_month = as.integer(substr(observation_date, 6L, 7L))
)]
base_cpi_values <- cpi[sale_year == 2022L, chicago_cpi_all_items]
base_cpi <- mean(base_cpi_values)
cpi <- cpi[
  sale_year %between% c(start_year, end_year),
  .(sale_year, sale_month, chicago_cpi_all_items)
]

if (nrow(cpi) != 12L * (end_year - start_year + 1L) ||
    anyDuplicated(cpi[, .(sale_year, sale_month)]) > 0L ||
    any(!is.finite(cpi$chicago_cpi_all_items)) ||
    length(base_cpi_values) != 12L ||
    !is.finite(base_cpi) || base_cpi <= 0) {
  stop("Chicago CPI does not cover the requested sample and base year.", call. = FALSE)
}

home_sales[cpi, on = .(sale_year, sale_month), `:=`(
  sale_price_cpi_chicago_all_items = i.chicago_cpi_all_items,
  sale_price_deflator_to_2022 = base_cpi / i.chicago_cpi_all_items
)]
home_sales[, `:=`(
  sale_price_real_2022 = sale_price_nominal * sale_price_deflator_to_2022,
  price_per_building_sqft_real_2022 =
    sale_price_nominal * sale_price_deflator_to_2022 / res_char_bldg_sf
)]

if (any(!is.finite(home_sales$sale_price_real_2022)) ||
    any(home_sales$sale_price_real_2022 <= 0) ||
    any(!is.finite(home_sales$price_per_building_sqft_real_2022)) ||
    any(home_sales$price_per_building_sqft_real_2022 <= 0)) {
  stop("Clean home sales contain an invalid real price.", call. = FALSE)
}

setorder(home_sales, sale_date, row_id)
output_file <- sprintf("../output/home_sales_%d_%d.csv", start_year, end_year)
fwrite(home_sales, output_file, na = "NA")
cat(sprintf("Wrote %s clean home sales to %s.\n", format(nrow(home_sales), big.mark = ","), output_file))

report <- capture.output({
  cat("CSV SHA-256:", digest::digest(output_file, file = TRUE, algo = "sha256"), "\n")
  report_data(home_sales, sprintf("home_sales_%d_%d", start_year, end_year), "row_id")
})
writeLines(trimws(report, which = "right"), sprintf("../report/home_sales_%d_%d.txt", start_year, end_year))
