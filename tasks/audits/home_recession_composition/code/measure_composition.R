# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_recession_composition/code")
suppressPackageStartupMessages({library(data.table);library(rvest);library(sf)})
source("../../../shared/code/report_data.R")
a <- readRDS("../input/assessments.rds")
overview <- readRDS("../input/overview.rds")
distress <- readRDS("../input/distress.rds")
sales <- copy(a$sales)
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(overview$sites$school_site_id),
 !anyDuplicated(distress$records$row_id),all(sales$row_id %in% distress$records$row_id))
# Many sales per site; one seller classification per transaction. Preserve all rows.
sales <- merge(sales,overview$sites[,.(school_site_id,school_names)],by="school_site_id",all.x=TRUE)
seller_flags <- distress$records[,.(row_id,seller_known,narrow_seller,broad_seller,bank_lender_seller)]
sales <- merge(sales,seller_flags,by="row_id",all.x=TRUE)
raw <- fread("../input/raw_sales.csv",colClasses="character",select=c("row_id","sale_buyer_name","sale_document_num","sale_price"))
setnames(raw,"sale_price","sale_price_nominal")
raw[,sale_price_nominal:=as.numeric(sale_price_nominal)]
stopifnot(!anyDuplicated(raw$row_id),all(sales$row_id %in% raw$row_id))
sales <- merge(sales,raw,by="row_id",all.x=TRUE)
sales[,buyer:=trimws(gsub(" +"," ",gsub("[^A-Z0-9 ]"," ",toupper(sale_buyer_name))))]
sales[,buyer_known:=!is.na(buyer) & !buyer %in% c("","UNKNOWN","NOT AVAILABLE","NOT PROVIDED","N A","NA")]
# A corporate legal suffix is an observable name feature, not proof of investment
# intent or distress. Personal names and trusts can also hold investment property.
sales[,organization_buyer:=buyer_known & grepl("(^| )(LLC|L L C|INC|INCORPORATED|CORP|CORPORATION|LTD|LIMITED|LLP|L L P|LP|L P)( |$)",buyer)]
sales[,c("buyer","sale_buyer_name"):=NULL]
sales[,seller_type:=fcase(!seller_known,"Unknown seller",narrow_seller,"Judicial/GSE/HUD seller",
 broad_seller,"Other bank/lender name",default="Other known seller")]
sales[,`:=`(under_50k=price<50000,townhouse=analysis_class==295,
 log_price_to_initial=fifelse(assessment_usable,log_price-log_initial_value,NA_real_))]
stopifnot(nrow(sales)==nrow(a$sales),!anyDuplicated(sales$row_id),!anyNA(sales$seller_known),!anyNA(sales$school_names))

# Read the unchanged original public-data bytes. Names uniquely identify the 77
# community areas; Chicago Total is a separately reported citywide benchmark.
extract_dir <- tempfile("context_extract_",tmpdir="../temp");dir.create(extract_dir)
stopifnot(setequal(untar("../output/context_snapshot.tar.gz",list=TRUE),c("ihs_foreclosures.html","community_areas.geojson","source.json")))
untar("../output/context_snapshot.tar.gz",exdir=extract_dir)
context_sources <- jsonlite::fromJSON(file.path(extract_dir,"source.json"))
for(i in seq_len(nrow(context_sources$sources))) stopifnot(digest::digest(file=file.path(extract_dir,context_sources$sources$filename[i]),algo="sha256")==context_sources$sources$sha256[i])
foreclosure_wide <- as.data.table(read_html(file.path(extract_dir,"ihs_foreclosures.html")) |> html_element("table#focus") |> html_table(convert=FALSE))
foreclosures <- melt(foreclosure_wide,id.vars="Geography",variable.name="sale_year",value.name="filings_per_100")
setnames(foreclosures,"Geography","community")
foreclosures[,`:=`(sale_year=as.integer(as.character(sale_year)),
 filings_per_100=as.numeric(fifelse(filings_per_100 %in% c("--",""),NA_character_,filings_per_100)),
 community_key=gsub("[^A-Z]","",toupper(community)))]
stopifnot(!anyDuplicated(foreclosures[,.(community_key,sale_year)]),
 all(foreclosures$filings_per_100>=0,na.rm=TRUE))
areas <- st_read(file.path(extract_dir,"community_areas.geojson"),quiet=TRUE)
stopifnot(nrow(areas)==77L,st_crs(areas)$epsg==4326,all(st_is_valid(areas)))
areas <- st_transform(areas,3435)
areas$community_key <- gsub("[^A-Z]","",toupper(areas$community))
stopifnot(!anyDuplicated(areas$community_key),setequal(areas$community_key,foreclosures[community!="Chicago Total",community_key]))
# One sale point per transaction, already in EPSG:3435 feet. Every point must
# intersect exactly one community polygon; no nearest-area substitutions.
points <- overview$map_sales[row_id %in% sales$row_id]
stopifnot(!anyDuplicated(points$row_id),setequal(points$row_id,sales$row_id))
area_match <- st_intersects(st_as_sf(points,coords=c("x","y"),crs=3435),areas)
stopifnot(all(lengths(area_match)==1L))
locations <- points[,.(row_id)]
locations[,community_key:=areas$community_key[unlist(area_match)]]
sales <- merge(sales,locations,by="row_id",all.x=TRUE)
stopifnot(nrow(sales)==nrow(a$sales),!anyNA(sales$community_key))
# Fixed 2008-11 transaction shares keep the geographic mix constant across the
# external foreclosure series. These are area exposures, not ring filing rates.
area_weights <- sales[sale_year<=2011,.(pre_sales=.N),by=.(group,community_key)]
area_weights[,weight:=pre_sales/sum(pre_sales),by=group]
area_rates <- merge(area_weights,foreclosures[sale_year %between% c(2005,2018)],by="community_key",allow.cartesian=TRUE)
stopifnot(nrow(area_rates)==nrow(area_weights)*14L,!anyNA(area_rates$filings_per_100),
 !anyDuplicated(area_rates[,.(group,community_key,sale_year)]))
foreclosure_exposure <- area_rates[,.(filings_per_100=sum(weight*filings_per_100)),by=.(group,sale_year)]
foreclosure_exposure <- rbind(foreclosure_exposure,foreclosures[community=="Chicago Total" & sale_year %between% c(2005,2018),
 .(group="Chicago total",sale_year,filings_per_100)])

annual <- sales[,.(sales=.N,median_price=median(price),mean_log_price=mean(log_price),
 mean_sqft=mean(res_char_bldg_sf),median_sqft=as.numeric(median(res_char_bldg_sf)),median_age=as.numeric(median(age_at_sale)),
 townhouse_share=mean(townhouse),under_50k_share=mean(under_50k),
 seller_coverage=mean(seller_known),narrow_seller_share=sum(narrow_seller)/sum(seller_known),
 broad_seller_share=sum(broad_seller)/sum(seller_known),buyer_coverage=mean(buyer_known),
 organization_buyer_share=sum(organization_buyer)/sum(buyer_known)),by=.(group,sale_year)]
matched <- sales[assessment_usable==TRUE]
parcel_year <- unique(matched[,.(pin,group,school_site_id,sale_year,initial_assessed_total)])
stopifnot(!anyDuplicated(parcel_year[,.(pin,sale_year)]))
parcel_annual <- parcel_year[,.(parcels=.N,median_initial=median(initial_assessed_total)),by=.(group,sale_year)]
repeat_pins <- matched[group=="Closed" & sale_year==2012,.N,by=pin][N>1,pin]
repeated_2012 <- matched[group=="Closed" & sale_year==2012 & pin %in% repeat_pins,
 .(row_id,pin,school_names,sale_date,sale_document_num,sale_price_nominal,initial_assessed_total)]
stopifnot(nrow(repeated_2012)==10L,uniqueN(repeated_2012$pin)==5L,!anyNA(repeated_2012$sale_document_num),
 !anyDuplicated(repeated_2012$sale_document_num),repeated_2012[,all(uniqueN(sale_date)==.N & uniqueN(sale_price_nominal)==.N),by=pin]$V1)
initial_annual <- matched[,.(sales=.N,parcels=uniqueN(pin),mean_initial=mean(initial_assessed_total),
 median_initial=median(initial_assessed_total),share_above_25k=mean(initial_assessed_total>=25000),
 mean_log_ratio=mean(log_price_to_initial)),by=.(group,sale_year)]
site_year <- matched[,.(sales=.N,mean_initial=mean(initial_assessed_total),median_initial=median(initial_assessed_total),
 mean_log_price=mean(log_price),median_sqft=as.numeric(median(res_char_bldg_sf)),above_25k=sum(initial_assessed_total>=25000)),
 by=.(group,school_site_id,school_names,sale_year)]
site_year[,sale_share:=sales/sum(sales),by=.(group,sale_year)]
median_neighbors <- matched[group=="Closed" & sale_year==2012][order(initial_assessed_total,row_id)]
median_neighbors[,rank:=.I]
median_neighbors <- median_neighbors[rank %in% 60:75,.(rank,row_id,pin,school_names,initial_assessed_total,price)]
stopifnot(nrow(median_neighbors)==16L)

# Weighted medians average adjacent values when cumulative weight equals 1/2,
# reproducing the ordinary median when every sale has the same weight.
weighted_median <- function(x,w) {
 order_x <- order(x);x <- x[order_x];w <- w[order_x]/sum(w)
 cumulative <- cumsum(w);i <- which(cumulative>=.5-1e-12)[1]
 if(abs(cumulative[i]-.5)<1e-12 && i<length(x)) mean(x[c(i,i+1)]) else x[i]
}
common_sites <- site_year[sale_year<=2013,.(years=.N),by=.(group,school_site_id)][years==6L]
common <- matched[sale_year<=2013 & school_site_id %in% common_sites$school_site_id]
fixed_weights <- common[sale_year<=2011,.(pre_sales=.N),by=.(group,school_site_id)]
fixed_weights[,site_weight:=pre_sales/sum(pre_sales),by=group]
common <- merge(common,fixed_weights,by=c("group","school_site_id"),all.x=TRUE)
common[,sale_weight:=site_weight/.N,by=.(group,school_site_id,sale_year)]
stopifnot(common[,all(abs(sum(sale_weight)-1)<1e-10),by=.(group,sale_year)]$V1)
fixed_mix <- rbind(initial_annual[sale_year<=2013,.(group,sale_year,median_initial,sales,series="All matched sales")],
 common[,.(median_initial=median(initial_assessed_total),sales=.N,series="Common sites: transaction weights"),by=.(group,sale_year)],
 common[,.(median_initial=weighted_median(initial_assessed_total,sale_weight),sales=.N,series="Common sites: fixed 2008-11 site shares"),by=.(group,sale_year)])
# Mean decomposition for 2011-12 on the common sites separates changing site
# shares from changing houses within sites, symmetrically between the two years.
decomposition <- dcast(site_year[school_site_id %in% common_sites$school_site_id & sale_year %in% c(2011,2012)],
 group+school_site_id+school_names~sale_year,value.var=c("sales","mean_initial"))
decomposition[,`:=`(share_2011=sales_2011/sum(sales_2011),share_2012=sales_2012/sum(sales_2012)),by=group]
decomposition[,`:=`(between_sites=(share_2012-share_2011)*(mean_initial_2012+mean_initial_2011)/2,
 within_sites=(share_2012+share_2011)/2*(mean_initial_2012-mean_initial_2011))]
mean_decomposition <- decomposition[,.(mean_2011=sum(share_2011*mean_initial_2011),
 mean_2012=sum(share_2012*mean_initial_2012),between_sites=sum(between_sites),within_sites=sum(within_sites)),by=group]
stopifnot(all(abs(mean_decomposition[,mean_2012-mean_2011-between_sites-within_sites])<1e-8))

# Compare consecutive observed pre-closure sales in different calendar years.
# These are selected resale pairs; price changes are not annualized returns.
pairs <- copy(sales[sale_year<=2012]);setorder(pairs,pin,sale_date,row_id)
pairs[,`:=`(previous_row=shift(row_id),previous_year=shift(sale_year),previous_price=shift(price)),by=pin]
pairs <- pairs[!is.na(previous_row) & sale_year>previous_year]
pairs[,real_change:=price/previous_price-1]
pair_summary <- pairs[,.(pairs=.N,parcels=uniqueN(pin),median_change=median(real_change),
 loss_share=mean(real_change<0)),by=.(group,sale_year)]
setorder(sales,row_id);setorder(annual,group,sale_year);setorder(initial_annual,group,sale_year)
setorder(parcel_year,pin,sale_year);setorder(parcel_annual,group,sale_year);setorder(repeated_2012,pin,sale_date)
setorder(site_year,group,school_site_id,sale_year);setorder(fixed_mix,series,group,sale_year)
setorder(foreclosures,community_key,sale_year);setorder(area_weights,group,community_key)
setorder(area_rates,group,community_key,sale_year);setorder(foreclosure_exposure,group,sale_year)
setorder(decomposition,group,school_site_id);setorder(mean_decomposition,group);setorder(pairs,row_id);setorder(pair_summary,group,sale_year)
sources <- data.table(source=c("../input/assessments.rds","../input/overview.rds","../input/distress.rds","../input/raw_sales.csv","../output/context_snapshot.tar.gz"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
saveRDS(list(sales=sales,annual=annual,initial_annual=initial_annual,parcel_year=parcel_year,parcel_annual=parcel_annual,
 repeated_2012=repeated_2012,site_year=site_year,median_neighbors=median_neighbors,
 fixed_mix=fixed_mix,common_sites=common_sites,fixed_weights=fixed_weights,decomposition=decomposition,mean_decomposition=mean_decomposition,
 foreclosures=foreclosures,area_weights=area_weights,area_rates=area_rates,foreclosure_exposure=foreclosure_exposure,
 pairs=pairs,pair_summary=pair_summary,sources=sources,context_sources=context_sources),"../output/composition.rds")
writeLines(trimws(capture.output({
 cat("RDS SHA-256:",digest::digest(file="../output/composition.rds",algo="sha256"),"\n")
 report_data(sales,"sales","row_id")
 report_data(annual,"annual",c("group","sale_year"))
 report_data(initial_annual,"initial_annual",c("group","sale_year"))
 report_data(parcel_year,"parcel_year",c("pin","sale_year"))
 report_data(parcel_annual,"parcel_annual",c("group","sale_year"))
 report_data(repeated_2012,"repeated_2012","row_id")
 report_data(site_year,"site_year",c("school_site_id","sale_year"))
 report_data(median_neighbors,"median_neighbors","rank")
 report_data(fixed_mix,"fixed_mix",c("group","sale_year","series"))
 report_data(common_sites,"common_sites",c("group","school_site_id"))
 report_data(fixed_weights,"fixed_weights",c("group","school_site_id"))
 report_data(decomposition,"decomposition",c("group","school_site_id"))
 report_data(mean_decomposition,"mean_decomposition","group")
 report_data(foreclosures,"foreclosures",c("community_key","sale_year"))
 report_data(area_weights,"area_weights",c("group","community_key"))
 report_data(area_rates,"area_rates",c("group","community_key","sale_year"))
 report_data(foreclosure_exposure,"foreclosure_exposure",c("group","sale_year"))
 report_data(pairs,"pairs","row_id")
 report_data(pair_summary,"pair_summary",c("group","sale_year"))
 report_data(sources,"sources","source")
}),which="right"),"../report/composition.txt")
print(initial_annual[group=="Closed" & sale_year %in% 2010:2013]);print(mean_decomposition)
print(fixed_mix[group=="Closed" & sale_year %in% 2011:2012]);print(annual[sale_year %in% 2010:2012])
print(foreclosure_exposure[sale_year<=2012]);print(pair_summary)
