# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sale_distress/code")
suppressPackageStartupMessages({library(data.table); library(DBI); library(duckdb)})
source("../../../shared/code/report_data.R")
overview <- readRDS("../input/overview.rds")
raw <- fread("../input/raw_sales.csv", colClasses="character",
 select=c("row_id","sale_seller_name","mydec_deed_type"))
sales <- fread("../input/corrected_sales.csv", colClasses=c(row_id="character",pin="character"),
 select=c("row_id","pin","sale_year","analysis_class","single_improvement_card","sale_price_nominal"))
con <- dbConnect(duckdb())
exposure <- as.data.table(dbGetQuery(con, "SELECT row_id, nearest_treated_site_id, nearest_control_site_id,
 nearest_treated_site_distance_feet, nearest_control_site_distance_feet,
 nearest_other_candidate_site_distance_feet, nearest_welcoming_school_distance_feet
 FROM read_parquet('../input/exposure.parquet')"))
dbDisconnect(con, shutdown=TRUE)
exposure[,row_id:=as.character(row_id)]
patterns <- fread("seller_patterns.csv")
metadata <- jsonlite::fromJSON("../output/sales_metadata.json")
source_columns <- as.data.table(metadata$columns)[!startsWith(fieldName,":"),.(field=fieldName,description)]
stopifnot(!anyDuplicated(source_columns$field), all(c("seller_name","buyer_name","mydec_deed_type") %in% source_columns$field),
 !any(grepl("reo|foreclos|short_sale|investor",source_columns$field)))

# One row per transaction, keyed by row_id, in each file. All master sales
# must match their original names and their previously validated exposure.
stopifnot(!anyNA(raw$row_id),!anyDuplicated(raw$row_id),!anyDuplicated(sales$row_id),
 !anyDuplicated(exposure$row_id),setequal(sales$row_id,exposure$row_id),all(sales$row_id %in% raw$row_id),
 overview$radius_miles==0.5,overview$end_year==2018L,overview$property_sample=="single_family")
sales <- merge(sales,exposure,by="row_id",all.x=TRUE,sort=FALSE)
sales <- sales[sale_year %between% c(2008L,2018L) & single_improvement_card &
 analysis_class %in% c(202:210,234,278,295) &
 nearest_other_candidate_site_distance_feet>2640 & nearest_welcoming_school_distance_feet>2640 &
 xor(nearest_treated_site_distance_feet<=2640,nearest_control_site_distance_feet<=2640)]
sales[,group:=fifelse(nearest_treated_site_distance_feet<=2640,"Closed","Stayed open")]
sales[,school_site_id:=fifelse(group=="Closed",nearest_treated_site_id,nearest_control_site_id)]
sales[,in_packet:=row_id %in% overview$map_sales$row_id]
stopifnot(!anyDuplicated(overview$map_sales$row_id),
 setequal(sales[in_packet==TRUE,row_id],overview$map_sales$row_id),
 all(sales[in_packet==TRUE,group]==overview$map_sales$group[match(sales[in_packet==TRUE,row_id],overview$map_sales$row_id)]))
sales <- merge(sales,raw,by="row_id",all.x=TRUE,sort=FALSE)
stopifnot(!anyDuplicated(sales$row_id))

# Names are proxies, not a county distress classification. Normalize case,
# punctuation and spacing; keep the substantive matching rules in a source table.
sales[,seller:=trimws(gsub(" +"," ",gsub("[^A-Z0-9 ]"," ",toupper(sale_seller_name))))]
sales[,seller_known:=!is.na(seller) & !seller %in% c("","UNKNOWN","NOT AVAILABLE","NOT PROVIDED","N A","NA")]
stopifnot(!anyDuplicated(patterns$indicator),setequal(patterns$indicator,c("judicial_seller","gse_hud_seller","bank_lender_seller")))
for(i in seq_len(nrow(patterns))) sales[,(patterns$indicator[i]):=seller_known & grepl(patterns$pattern[i],seller)]
sales[,narrow_seller:=judicial_seller | gse_hud_seller]
sales[,broad_seller:=narrow_seller | bank_lender_seller]
sales[,deed_known:=!is.na(mydec_deed_type) & nzchar(trimws(mydec_deed_type))]
sales[,foreclosure_related_deed:=mydec_deed_type %in% c("Judicial Sale","Sheriff's Deed","Selling Officer's Deed","Deed in lieu of Foreclosure")]
sales[,in_lieu_deed:=mydec_deed_type=="Deed in lieu of Foreclosure" & deed_known]
stopifnot(!any(sales$narrow_seller & !sales$broad_seller),!any(sales$broad_seller & !sales$seller_known),
 !any(sales$foreclosure_related_deed & !sales$deed_known))

# Two explicitly nested populations: the fixed packet, and all single-family
# single-card transfers in the same geography before any price/quality screens.
# Each transaction appears once per population to which it belongs.
records <- sales[,.(row_id,pin,sale_year,group,school_site_id,in_packet,seller_known,
 judicial_seller,gse_hud_seller,bank_lender_seller,narrow_seller,broad_seller,
 deed_known,foreclosure_related_deed,in_lieu_deed)]
count_data <- rbind(copy(records)[,sample:="Before price screens"],records[in_packet==TRUE][,sample:="Packet"])
annual <- count_data[,.(sales=.N,parcels=uniqueN(pin),seller_known=sum(seller_known),
 judicial_seller=sum(judicial_seller),gse_hud_seller=sum(gse_hud_seller),bank_lender_seller=sum(bank_lender_seller),
 narrow_seller=sum(narrow_seller),broad_seller=sum(broad_seller),deed_known=sum(deed_known),
 foreclosure_related_deed=sum(foreclosure_related_deed),in_lieu_deed=sum(in_lieu_deed)),by=.(sample,group,sale_year)]
annual[,`:=`(seller_coverage=seller_known/sales,deed_coverage=deed_known/sales,
 narrow_share=narrow_seller/seller_known,broad_share=broad_seller/seller_known,
 narrow_share_all=narrow_seller/sales,broad_share_all=broad_seller/sales,
 deed_share=fifelse(deed_known>0,foreclosure_related_deed/deed_known,NA_real_))]
# Bounds reflect unknown seller names only, not missed matches or false positives.
annual[,`:=`(narrow_upper=(narrow_seller+sales-seller_known)/sales,
 broad_upper=(broad_seller+sales-seller_known)/sales)]
setorder(annual,sample,group,sale_year)
stopifnot(nrow(annual)==44L,all(annual$seller_known>0),all(annual$narrow_share<=annual$broad_share))
deeds <- sales[,.(records=.N,packet_sales=sum(in_packet)),by=.(sale_year,group,mydec_deed_type)]
setorder(deeds,sale_year,group,mydec_deed_type)
# Institutional matches permit inspection without publishing household names.
matches <- sales[broad_seller==TRUE,.(records=.N,packet_sales=sum(in_packet)),
 by=.(seller,judicial_seller,gse_hud_seller,bank_lender_seller)]
setorder(matches,-packet_sales,seller)
sources <- data.table(source=c("../input/raw_sales.csv","../input/corrected_sales.csv","../input/exposure.parquet", "../input/overview.rds","../output/sales_metadata.json","seller_patterns.csv"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
setorder(records,row_id)
saveRDS(list(records=records,annual=annual,deeds=deeds,institutional_matches=matches,source_columns=source_columns,sources=sources),"../output/distress.rds")
writeLines(trimws(capture.output({
 cat("Saved RDS SHA-256:",digest::digest(file="../output/distress.rds",algo="sha256"),"\n")
 cat("Seller-name proxies do not certify distress; unknown names are not classified. Public metadata inspected September 15, 2026.\n")
 report_data(records,"records","row_id")
 report_data(annual,"annual",c("sample","group","sale_year"))
 report_data(deeds,"deeds",c("sale_year","group","mydec_deed_type"))
 report_data(matches,"institutional_matches","seller")
 report_data(source_columns,"source_columns","field")
 report_data(sources,"sources","source")
}),which="right"),"../report/distress.txt")
print(annual[sample=="Packet",.(sale_year,group,sales,seller_coverage,narrow_share,broad_share,deed_coverage)])
print(annual[sale_year==2010,.(sample,group,sales,narrow_seller,broad_seller,narrow_share,broad_share)])
