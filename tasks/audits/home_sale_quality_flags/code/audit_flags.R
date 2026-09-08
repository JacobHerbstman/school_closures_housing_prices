# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sale_quality_flags/code")
library(data.table)
library(DBI)
library(duckdb)
flags <- c("sale_filter_same_sale_within_365", "sale_filter_less_than_10k", "sale_filter_deed_type")
raw <- fread("../input/raw_sales.csv", select=c("row_id", flags), colClasses="character")
master <- fread("../input/master.csv", colClasses=c(row_id="character", pin="character"))
sales <- fread("../input/corrected.csv", select=c("row_id", "pin", "sale_year", "sale_price_nominal", "sale_deed_type", flags),
               colClasses=c(row_id="character", pin="character"))
# All three files contain one row per transaction. Match the retained universe by row_id.
stopifnot(!anyNA(raw$row_id), !anyDuplicated(raw$row_id), !anyDuplicated(master$row_id),
          !anyDuplicated(sales$row_id), setequal(master$row_id, sales$row_id))
raw_index <- match(master$row_id, raw$row_id)
corrected_index <- match(master$row_id, sales$row_id)
stopifnot(!anyNA(raw_index), !anyNA(corrected_index))
for (flag in flags) {
  value <- tolower(trimws(raw[[flag]]))
  stopifnot(!anyNA(value), all(value %in% c("true", "false")),
            identical(value[raw_index]=="true", master[[flag]]),
            identical(master[[flag]], sales[[flag]][corrected_index]))
}
stopifnot(identical(master$sale_price_nominal, sales$sale_price_nominal[corrected_index]),
          all(master$sale_filter_less_than_10k == (master$sale_price_nominal <= 10000)))
checks <- data.table(check=c("Raw flag values are explicit true/false", "All master flags match raw source by row_id",
 "All corrected flags match master by row_id", "Low-price flag equals nominal price <= 10000"),
 transactions=c(nrow(raw), rep(nrow(master),3L)))
sales <- sales[sale_year %between% c(2008L,2018L)]
# Exposure is also unique by transaction ID; every corrected record must have an exposure row.
con <- dbConnect(duckdb())
exposure <- as.data.table(dbGetQuery(con, "SELECT row_id, focal_exposure_025, n_welcoming_schools_025, n_other_candidate_sites_025 FROM read_parquet('../input/exposure.parquet')"))
dbDisconnect(con, shutdown=TRUE)
exposure[, row_id:=as.character(row_id)]
stopifnot(!anyDuplicated(exposure$row_id), all(sales$row_id %in% exposure$row_id))
sales <- merge(sales, exposure, by="row_id", all.x=TRUE, sort=FALSE)
sales[, group:=fcase(focal_exposure_025=="treated_only" & n_welcoming_schools_025==0 & n_other_candidate_sites_025==0, "Closed",
 focal_exposure_025=="control_only" & n_welcoming_schools_025==0 & n_other_candidate_sites_025==0, "Stayed open", default="Outside comparison")]
# Assign overlaps to low price first. This is accounting, not a change to the union of flags.
sales[, reason:=fcase(sale_filter_less_than_10k, "Price <= $10,000", sale_filter_deed_type, "Deed type, price > $10,000",
 sale_filter_same_sale_within_365, "Repeat, price > $10,000 and deed passes", default="Pass all three")]
sales[, price_band:=fcase(sale_price_nominal==0, "$0", sale_price_nominal==1, "$1", sale_price_nominal<10000, "Other below $10,000",
 sale_price_nominal==10000, "Exactly $10,000", default="Above $10,000")]
# Citywide is a separate summary population; comparison groups remain disjoint.
count_data <- rbind(sales[, .(group="Citywide", sale_year, sale_deed_type, sale_price_nominal, price_band, reason,
 sale_filter_same_sale_within_365, sale_filter_less_than_10k, sale_filter_deed_type)],
 sales[group!="Outside comparison", .(group, sale_year, sale_deed_type, sale_price_nominal, price_band, reason,
 sale_filter_same_sale_within_365, sale_filter_less_than_10k, sale_filter_deed_type)])
summary <- count_data[, .(records=.N, pass=sum(reason=="Pass all three"), excluded=sum(reason!="Pass all three"),
 low=sum(sale_filter_less_than_10k), deed_after_low=sum(reason=="Deed type, price > $10,000"),
 repeat_after_low_deed=sum(reason=="Repeat, price > $10,000 and deed passes"),
 low_zero_or_one=sum(sale_filter_less_than_10k & sale_price_nominal %in% c(0,1))), by=group][order(group)]
stopifnot(all(summary$excluded==summary$low+summary$deed_after_low+summary$repeat_after_low_deed))
combinations <- count_data[, .(records=.N), by=c("group",flags)][order(group, sale_filter_less_than_10k, sale_filter_deed_type, sale_filter_same_sale_within_365)]
annual <- count_data[, .(records=.N), by=.(group, sale_year, reason)][order(group, sale_year, reason)]
prices <- count_data[, .(records=.N), by=.(group, reason, price_band)][order(group, reason, price_band)]
deed <- count_data[, .(records=.N, median_price=median(sale_price_nominal)), by=.(group, sale_deed_type, sale_filter_deed_type, sale_filter_less_than_10k)][order(group, sale_deed_type, sale_filter_deed_type, sale_filter_less_than_10k)]
# Empty strings and NULL become indistinguishable in the export. Check only observed deed types.
stopifnot(all(sales[sale_deed_type!="" & !is.na(sale_deed_type), sale_filter_deed_type ==
 (sale_deed_type %in% c("Quit claim", "Executor", "Beneficial interest"))]))
# Independently reconcile all first-stage packet counts, including group-by-year counts.
overview <- readRDS("../input/data_review.rds")
packet <- dcast(overview$attrition[step %in% 1:2], group~step, value.var="sales")
comparison <- merge(summary, packet, by="group")
stopifnot(nrow(comparison)==3L, all(comparison$records==comparison$`1`), all(comparison$pass==comparison$`2`))
annual_check <- count_data[group!="Citywide", .(sales=.N), by=.(group,sale_year)]
annual_check <- merge(annual_check, overview$annual_counts[stage==1,.(group,sale_year,packet_sales=sales)], by=c("group","sale_year"), all=TRUE)
stopifnot(!anyNA(annual_check), all(annual_check$sales==annual_check$packet_sales))
checks <- rbind(checks, data.table(check=c("Observable deed types match county flag", "Packet before/after flag counts match", "Packet annual source counts match"),
 transactions=c(sales[sale_deed_type!="" & !is.na(sale_deed_type),.N], nrow(sales), sum(summary[group!="Citywide",records]))))
sources <- data.table(source=c("../input/raw_sales.csv", "../input/master.csv", "../input/corrected.csv", "../input/exposure.parquet", "../input/data_review.rds", "../output/county_sale.sql"))
sources[, sha256:=vapply(source, digest::digest, character(1), file=TRUE, algo="sha256")]
saveRDS(list(summary=summary, combinations=combinations, annual=annual, prices=prices, deed=deed, checks=checks, sources=sources), "../output/sale_flags.rds")
print(summary)
