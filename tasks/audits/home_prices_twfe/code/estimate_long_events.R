# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
# property_sample <- "all"
# radius_miles <- 0.25
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
property_sample <- args[1]
radius_miles <- as.numeric(args[2])
stopifnot(radius_miles %in% c(0.25,0.5),property_sample=="single_family" || radius_miles==0.25)
radius_suffix <- if(radius_miles==0.25) "" else "_0.5"
stopifnot(property_sample %in% c("all","single_family"))
end_year <- if(property_sample=="single_family") 2018L else 2023L
suppressPackageStartupMessages({library(data.table);library(DBI);library(duckdb);library(fixest)})
audit <- if(property_sample=="single_family") readRDS(paste0("../input/overview_single_family",radius_suffix,".rds")) else readRDS("../input/overview_through_2023.rds")
stopifnot(audit$end_year==end_year,audit$radius_miles==radius_miles)
sales <- fread("../input/corrected_sales.csv",colClasses=c(row_id="character",pin="character"))
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(audit$map_sales$row_id),all(audit$map_sales$row_id %in% sales$row_id))
sales <- merge(sales,audit$map_sales[,.(row_id,group)],by="row_id")
# Restore the existing regression completeness requirements on the exact packet IDs.
sales <- sales[is.finite(res_char_bldg_sf) & res_char_bldg_sf>0 & is.finite(res_char_land_sf) & res_char_land_sf>0 &
 is.finite(res_char_yrblt) & is.finite(res_char_beds) & is.finite(res_char_rooms) & is.finite(res_char_fbath) &
 !is.na(res_char_type_resd) & nzchar(trimws(res_char_type_resd)) & !is.na(res_char_cnst_qlty) & nzchar(trimws(res_char_cnst_qlty)) &
 !is.na(res_char_repair_cnd) & nzchar(trimws(res_char_repair_cnd)) & (analysis_class!=211 | res_char_apts %in% c("Two","Three","Four","Five","Six"))]
cpi <- fread("../input/cpi.csv")
cpi[,`:=`(sale_year=as.integer(substr(observation_date,1,4)),sale_month=as.integer(substr(observation_date,6,7)))]
stopifnot(!anyDuplicated(cpi[,.(sale_year,sale_month)]))
sales[cpi,on=.(sale_year,sale_month),sale_price_real_2022:=sale_price_nominal*cpi[sale_year==2022,mean(chicago_cpi_all_items)]/i.chicago_cpi_all_items]
con <- dbConnect(duckdb(),dbdir=":memory:")
exposure <- as.data.table(dbGetQuery(con,"SELECT row_id, nearest_treated_site_id, nearest_control_site_id FROM read_parquet('../input/home_school_exposure_2006_2025.parquet')"))
dbDisconnect(con,shutdown=TRUE)
exposure[,row_id:=as.character(row_id)]
stopifnot(!anyDuplicated(exposure$row_id),all(sales$row_id %in% exposure$row_id))
sales <- merge(sales,exposure,by="row_id",all.x=TRUE)
sales[,`:=`(treated=as.integer(group=="Closed"),school_site_id=fifelse(group=="Closed",nearest_treated_site_id,nearest_control_site_id),
 log_real_price=log(sale_price_real_2022),log_building_sqft=log(res_char_bldg_sf),log_land_sqft=log(res_char_land_sf),age_at_sale=sale_year-res_char_yrblt,
 apartments=fifelse(analysis_class==211,match(res_char_apts,c("Two","Three","Four","Five","Six"))+1L,0L))]
stopifnot(!anyNA(sales$school_site_id),all(sales$age_at_sale>=0))
if(property_sample=="single_family") stopifnot(all(sales$analysis_class %in% c(202:210,234,278,295)))
support <- sales[,.(sales=.N,mean_price=mean(sale_price_real_2022)),by=.(group,sale_year)]
check <- merge(support,audit$complete_prices,by=c("group","sale_year"))
stopifnot(nrow(check)==2L*(end_year-2008L+1L),all(check$sales.x==check$sales.y),max(abs(check$mean_price.x-check$mean_price.y))<1e-7)
# Formulae match the four existing annual transaction-weighted models.
formulas <- list(
 event_log=log_real_price ~ i(sale_year,treated,ref=2012) | school_site_id+sale_year,
 event_dollars=sale_price_real_2022 ~ i(sale_year,treated,ref=2012) | school_site_id+sale_year,
 event_hedonic_log=log_real_price ~ i(sale_year,treated,ref=2012)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+apartments+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year,
 event_hedonic_dollars=sale_price_real_2022 ~ i(sale_year,treated,ref=2012)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+apartments+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year)
# Apartment count is identically zero in a single-family sample.
if(property_sample=="single_family") {
 formulas$event_hedonic_log <- log_real_price ~ i(sale_year,treated,ref=2012)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year
 formulas$event_hedonic_dollars <- sale_price_real_2022 ~ i(sale_year,treated,ref=2012)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year
}
if(property_sample=="all") baseline <- fread("../output/coefficients.csv")
coefficients <- list();summaries <- list()
for(name in names(formulas)) {
 if(property_sample=="all") {
 old <- feols(formulas[[name]],data=sales[sale_year<=2018],vcov=~school_site_id)
 old_events <- coef(old)[grepl("sale_year::",names(coef(old)))]
 expected <- baseline[model==name]
 stopifnot(setequal(names(old_events),expected$term),max(abs(old_events[expected$term]-expected$estimate))<1e-6)
 }
 fit <- feols(formulas[[name]],data=sales,vcov=~school_site_id)
 stopifnot(nobs(fit)==nrow(sales))
 d <- as.data.table(coeftable(fit),keep.rownames="term")
 setnames(d,c("term","estimate","std_error","t_value","p_value"))
 ci <- confint(fit)
 d[,`:=`(conf_low=ci[,1],conf_high=ci[,2],model=name)]
 d <- d[grepl("sale_year::",term)]
 d[,sale_year:=as.integer(sub("sale_year::([0-9]+):treated","\\1",term))]
 stopifnot(setequal(d$sale_year,setdiff(2008:end_year,2012)))
 test <- wald(fit,keep="sale_year::(2008|2009|2010|2011):treated",print=FALSE)
 test$p <- pf(test$stat,test$df1,uniqueN(sales$school_site_id)-1,lower.tail=FALSE)
 coefficients[[name]] <- d
 summaries[[name]] <- data.table(model=name,observations=nobs(fit),sites=uniqueN(sales$school_site_id),pretrend_p=test$p,fixest_version=as.character(packageVersion("fixest")))
}
coefficients <- rbindlist(coefficients);summaries <- rbindlist(summaries)
setorder(coefficients,model,sale_year);setorder(support,group,sale_year)
saveRDS(list(property_sample=property_sample,radius_miles=radius_miles,end_year=end_year,coefficients=coefficients,summaries=summaries,support=support),if(property_sample=="single_family") paste0("../output/single_family_events",radius_suffix,".rds") else "../output/long_events.rds")
print(summaries)
print(coefficients[sale_year==end_year,.(model,estimate,conf_low,conf_high)])
