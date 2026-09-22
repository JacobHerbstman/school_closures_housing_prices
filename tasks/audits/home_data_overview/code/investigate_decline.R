# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
suppressPackageStartupMessages({library(data.table);library(DBI);library(duckdb)})
audit <- readRDS("../output/data_review.rds")
stopifnot(audit$radius_miles==0.25)
sales <- fread("../input/corrected_sales.csv",colClasses=c(row_id="character",pin="character"))
raw <- sales[,.(row_id,sale_year,sale_month,sale_price_nominal,sale_type,sale_filter_same_sale_within_365,sale_filter_less_than_10k,sale_filter_deed_type)]
# One saved packet observation per transaction; use its IDs rather than rebuilding cleaning.
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(audit$map_sales$row_id),all(audit$map_sales$row_id %in% sales$row_id))
sales <- merge(sales,audit$map_sales[,.(row_id,group)],by="row_id")
con <- dbConnect(duckdb(),dbdir=":memory:")
exposure <- as.data.table(dbGetQuery(con,"SELECT row_id, nearest_treated_site_id, nearest_control_site_id, focal_exposure_025, n_welcoming_schools_025, n_other_candidate_sites_025 FROM read_parquet('../input/exposure.parquet')"))
dbDisconnect(con,shutdown=TRUE)
exposure[,row_id:=as.character(row_id)]
raw <- merge(raw,exposure,by="row_id",all.x=TRUE)
raw <- raw[sale_year %between% c(2008L,2018L) & focal_exposure_025 %in% c("treated_only","control_only") & n_welcoming_schools_025==0 & n_other_candidate_sites_025==0]
raw[,school_site_id:=fifelse(focal_exposure_025=="treated_only",nearest_treated_site_id,nearest_control_site_id)]
coverage <- raw[,.(recorded=.N,market=sum(!sale_filter_same_sale_within_365 & !sale_filter_less_than_10k & !sale_filter_deed_type & sale_price_nominal>10000 & !is.na(sale_type) & sale_type!="LAND")),by=.(school_site_id,sale_year)]
stopifnot(!anyDuplicated(exposure$row_id),all(sales$row_id %in% exposure$row_id))
sales <- merge(sales,exposure,by="row_id",all.x=TRUE)
sales[,school_site_id:=fifelse(group=="Closed",nearest_treated_site_id,nearest_control_site_id)]
stopifnot(!anyDuplicated(audit$sites$school_site_id),all(sales$school_site_id %in% audit$sites$school_site_id))
sales <- merge(sales,audit$sites[,.(school_site_id,school_names)],by="school_site_id",all.x=TRUE)
cpi <- fread("../input/cpi.csv")
cpi[,`:=`(sale_year=as.integer(substr(observation_date,1,4)),sale_month=as.integer(substr(observation_date,6,7)))]
stopifnot(!anyDuplicated(cpi[,.(sale_year,sale_month)]))
sales[cpi,on=.(sale_year,sale_month),real_price:=sale_price_nominal*cpi[sale_year==2022,mean(chicago_cpi_all_items)]/i.chicago_cpi_all_items]
sales[,property_type:=fifelse(analysis_class==211,"Apartment buildings","Houses/townhouses")]
sales[,real_ppsf:=fifelse(is.finite(res_char_bldg_sf) & res_char_bldg_sf>0,real_price/res_char_bldg_sf,NA_real_)]
annual <- sales[,.(sales=.N,mean=mean(real_price),median=median(real_price),p75=quantile(real_price,.75),p95=quantile(real_price,.95),nominal_mean=mean(sale_price_nominal),
 mean_ppsf=mean(real_ppsf,na.rm=TRUE),over_500k=sum(real_price>500000),over_1m=sum(real_price>1e6),
 contribution_over_500k=sum(real_price[real_price>500000])/.N,mean_below_500k=mean(real_price[real_price<=500000])),by=.(group,sale_year)]
check <- merge(annual,audit$annual_prices,by=c("group","sale_year"))
stopifnot(nrow(sales)==sum(audit$annual_prices$sales),max(abs(check$mean-check$mean_price))<1e-7,all(check$sales.x==check$sales.y))
site_year <- sales[,.(sales=.N,total=sum(real_price),mean=mean(real_price),median=median(real_price),over_500k=sum(real_price>500000),mean_ppsf=mean(real_ppsf,na.rm=TRUE)),by=.(group,school_site_id,school_names,sale_year)]
site_year[,share:=sales/sum(sales),by=.(group,sale_year)]
site_year[,contribution:=total/sum(sales),by=.(group,sale_year)]
# Exact additive contributions to the aggregate mean change, including sales mix.
changes <- list()
for(start in c(2016L,2017L)) {
 before <- site_year[sale_year==start,.(group,school_site_id,school_names,n_before=sales,mean_before=mean,share_before=share,contribution_before=contribution)]
 after <- site_year[sale_year==2018,.(group,school_site_id,school_names,n_after=sales,mean_after=mean,share_after=share,contribution_after=contribution)]
 d <- merge(before,after,by=c("group","school_site_id","school_names"),all=TRUE)
 for(v in c("n_before","n_after","share_before","share_after","contribution_before","contribution_after")) set(d,which(is.na(d[[v]])),v,0)
 d[,`:=`(start_year=start,change=contribution_after-contribution_before)]
 # Common-site midpoint decomposition. Entries/exits are reported separately.
 d[,within:=fifelse(n_before>0 & n_after>0,(share_before+share_after)/2*(mean_after-mean_before),0)]
 d[,mix:=change-within]
 changes[[as.character(start)]] <- d
}
changes <- rbindlist(changes)
setorder(changes,start_year,group,change)
for(start in c(2016L,2017L)) for(g in c("Closed","Stayed open")) stopifnot(abs(changes[start_year==start & group==g,sum(change)]-(annual[group==g & sale_year==2018,mean]-annual[group==g & sale_year==start,mean]))<1e-7)
# Omit each treated site separately; no re-estimation or replacement of the sample.
omissions <- rbindlist(lapply(unique(sales[group=="Closed",school_site_id]),function(id)
 sales[group=="Closed" & school_site_id!=id,.(mean=mean(real_price),median=median(real_price),sales=.N),by=sale_year][,omitted_site:=id]))
composition <- sales[,.(sales=.N,mean=mean(real_price),median=median(real_price),mean_ppsf=mean(real_ppsf,na.rm=TRUE)),by=.(group,sale_year,property_type)]
composition[,share:=sales/sum(sales),by=.(group,sale_year)]
monthly <- sales[,.(sales=.N,mean=mean(real_price)),by=.(group,sale_year,sale_month)]
# Inspect the transactions behind the upper tail without changing eligibility.
expensive <- sales[sale_year>=2015 & real_price>500000,.(row_id,pin,group,school_site_id,school_names,sale_year,sale_month,real_price,sale_price_nominal,property_type,res_char_bldg_sf,real_ppsf)]
setorder(expensive,group,sale_year,-real_price)
coverage <- merge(coverage,site_year[,.(school_site_id,sale_year,school_names,group,retained=sales)],by=c("school_site_id","sale_year"),all.x=TRUE)
stopifnot(all(coverage[!is.na(retained),retained<=market & market<=recorded]))
# Fixed 2016 sales weights, only sites observed in all three late years.
common <- site_year[sale_year>=2016,.(years=.N),by=.(group,school_site_id)][years==3]
fixed <- merge(site_year[sale_year>=2016],common[,.(group,school_site_id)],by=c("group","school_site_id"))
weights <- fixed[sale_year==2016,.(group,school_site_id,weight=sales)]
fixed <- merge(fixed,weights,by=c("group","school_site_id"))
fixed <- fixed[,.(fixed_mean=weighted.mean(mean,weight),observed_mean=weighted.mean(mean,sales),sites=.N,sales=sum(sales)),by=.(group,sale_year)]
# Fix the neighborhood price classification using only pre-closure sales.
pre_prices <- sales[sale_year<=2012,.(pre_sales=.N,pre_median=median(real_price)),by=.(school_site_id,school_names,group)]
cutoff <- median(pre_prices$pre_median)
pre_prices[,price_group:=fifelse(pre_median<=cutoff,"Below/equal pre-period median","Above pre-period median")]
stopifnot(!anyDuplicated(pre_prices$school_site_id))
classified <- merge(sales[,.(row_id,school_site_id,group,sale_year)],pre_prices[,.(school_site_id,price_group)],by="school_site_id",all.x=TRUE)
unclassified <- classified[is.na(price_group),.(sales=.N,sites=uniqueN(school_site_id)),by=group]
counts <- classified[!is.na(price_group),.(sales=.N),by=.(group,price_group,sale_year)]
pre_price_counts <- merge(CJ(group=c("Closed","Stayed open"),price_group=c("Below/equal pre-period median","Above pre-period median"),sale_year=2008:2018),counts,by=c("group","price_group","sale_year"),all.x=TRUE)
pre_price_counts[is.na(sales),sales:=0L]
stopifnot(sum(pre_price_counts$sales)+sum(unclassified$sales)==nrow(sales))
pre_price_definition <- data.table(cutoff=cutoff,sites=nrow(pre_prices),unclassified_sales=sum(unclassified$sales))
saveRDS(list(pre_prices=pre_prices,pre_price_counts=pre_price_counts,pre_price_definition=pre_price_definition,coverage=coverage,fixed=fixed,annual=annual,site_year=site_year,changes=changes,omissions=omissions,composition=composition,monthly=monthly,expensive=expensive),"../output/late_decline.rds")
print(annual[sale_year>=2015])
print(changes[group=="Closed" & start_year==2016][1:10])
