# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_scale_checks/code")
suppressPackageStartupMessages({library(data.table);library(DBI);library(duckdb);library(fixest)})
source("../../../shared/code/report_data.R")
packet <- readRDS("../input/overview.rds")
original <- readRDS("../input/original_events.rds")
stopifnot(packet$radius_miles==0.5,packet$end_year==2018L,packet$property_sample=="single_family")
sales <- fread("../input/corrected_sales.csv",colClasses=c(row_id="character",pin="character"))
# One transaction on both sides, using the packet's exact retained IDs.
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(packet$map_sales$row_id),all(packet$map_sales$row_id %in% sales$row_id))
sales <- merge(sales,packet$map_sales[,.(row_id,group)],by="row_id")
sales <- sales[is.finite(res_char_bldg_sf) & res_char_bldg_sf>0 & is.finite(res_char_land_sf) & res_char_land_sf>0 &
 is.finite(res_char_yrblt) & is.finite(res_char_beds) & is.finite(res_char_rooms) & is.finite(res_char_fbath) &
 !is.na(res_char_type_resd) & nzchar(trimws(res_char_type_resd)) & !is.na(res_char_cnst_qlty) & nzchar(trimws(res_char_cnst_qlty)) &
 !is.na(res_char_repair_cnd) & nzchar(trimws(res_char_repair_cnd))]
stopifnot(all(sales$analysis_class %in% c(202:210,234,278,295)))
cpi <- fread("../input/cpi.csv")
cpi[,`:=`(sale_year=as.integer(substr(observation_date,1,4)),sale_month=as.integer(substr(observation_date,6,7)))]
# Many transactions to one monthly CPI value.
stopifnot(!anyDuplicated(cpi[,.(sale_year,sale_month)]),cpi[sale_year==2022,.N]==12L)
sales[cpi,on=.(sale_year,sale_month),price:=sale_price_nominal*cpi[sale_year==2022,mean(chicago_cpi_all_items)]/i.chicago_cpi_all_items]
con <- dbConnect(duckdb(),dbdir=":memory:")
exposure <- as.data.table(dbGetQuery(con,"SELECT row_id, nearest_treated_site_id, nearest_control_site_id FROM read_parquet('../input/exposure.parquet')"))
dbDisconnect(con,shutdown=TRUE)
exposure[,row_id:=as.character(row_id)]
# One exposure row for each transaction.
stopifnot(!anyDuplicated(exposure$row_id),all(sales$row_id %in% exposure$row_id))
sales <- merge(sales,exposure,by="row_id",all.x=TRUE)
sales[,`:=`(treated=as.integer(group=="Closed"),school_site_id=fifelse(group=="Closed",nearest_treated_site_id,nearest_control_site_id),
 log_price=log(price),log_building_sqft=log(res_char_bldg_sf),log_land_sqft=log(res_char_land_sf),age_at_sale=sale_year-res_char_yrblt)]
sales[,treated_post:=treated*as.integer(sale_year>=2014)]
stopifnot(!anyDuplicated(sales$row_id),!anyNA(sales$school_site_id),all(is.finite(sales$price) & sales$price>0),all(sales$age_at_sale>=0))
support <- sales[,.(sales=.N,mean_price=mean(price)),by=.(group,sale_year)]
check <- merge(support,packet$complete_prices,by=c("group","sale_year"))
stopifnot(nrow(check)==22L,all(check$sales.x==check$sales.y),max(abs(check$mean_price.x-check$mean_price.y))<1e-7)
event_formulas <- list(
 without=y ~ i(sale_year,treated,ref=2012) | school_site_id+sale_year,
 with=y ~ i(sale_year,treated,ref=2012)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year)
did_formulas <- list(
 without=y ~ treated_post | school_site_id+sale_year,
 with=y ~ treated_post+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+sale_year)
coefficients <- list(); model_support <- list(); predictions <- list(); smearing <- list(); projections <- list()
for(control_spec in names(event_formulas)) {
 for(estimator in c("OLS log","OLS dollars","PPML")) {
  # PPML uses thousands of dollars for numerical scaling, without rounding.
  sales[,y:=switch(estimator,"OLS log"=log_price,"OLS dollars"=price,PPML=price/1000)]
  fit <- if(estimator=="PPML") fepois(event_formulas[[control_spec]],data=sales,vcov=~school_site_id,glm.iter=100,glm.tol=1e-10) else feols(event_formulas[[control_spec]],data=sales,vcov=~school_site_id)
  stopifnot(nobs(fit)==nrow(sales))
  if(estimator=="PPML") {
   stopifnot(isTRUE(fit$convStatus),all(is.finite(fitted(fit)) & fitted(fit)>0))
   # Group-year indicators imply these price totals agree at the optimum.
   score <- sales[,.(group,sale_year,error=price/1000-fitted(fit),price=price/1000)][,.(relative_score=sum(error)/sum(price)),by=.(group,sale_year)]
   stopifnot(max(abs(score$relative_score))<1e-5)
  } else {
   expected_name <- paste0("event_",if(control_spec=="with") "hedonic_" else "",if(estimator=="OLS log") "log" else "dollars")
   expected <- original$coefficients[model==expected_name]
   stopifnot(nrow(expected)==10L,max(abs(coef(fit)[expected$term]-expected$estimate))<1e-6)
  }
  if(estimator=="OLS log") log_fit <- fit
  if(estimator=="OLS dollars") levels_fit <- fit
  for(design_type in c("event","did")) {
   current <- if(design_type=="event") fit else if(estimator=="PPML") fepois(did_formulas[[control_spec]],data=sales[sale_year!=2013],vcov=~school_site_id,glm.iter=100,glm.tol=1e-10) else feols(did_formulas[[control_spec]],data=sales[sale_year!=2013],vcov=~school_site_id)
   stopifnot(nobs(current)==if(design_type=="event") nrow(sales) else sales[sale_year!=2013,.N])
   if(estimator=="PPML") stopifnot(isTRUE(current$convStatus))
   d <- as.data.table(coeftable(current),keep.rownames="term")
   setnames(d,c("term","estimate","std_error","t_value","p_value"))
   ci <- confint(current)
   d[,`:=`(conf_low=ci[,1],conf_high=ci[,2],controls=control_spec,estimator=estimator,design=design_type)]
   d <- d[grepl("sale_year::",term) | term=="treated_post"]
   d[,sale_year:=if(design_type=="event") as.integer(sub("sale_year::([0-9]+):treated","\\1",term)) else NA_integer_]
   coefficients[[length(coefficients)+1L]] <- d
   model_support[[length(model_support)+1L]] <- data.table(controls=control_spec,estimator=estimator,design=design_type,observations=nobs(current),sites=uniqueN(sales[if(design_type=="event") rep(TRUE,.N) else sale_year!=2013,school_site_id]))
  }
 }
 # E(price|X) = exp(fitted log price) * E(exp(error)|X).
 # A common smearing factor is an assumption, not a heteroskedasticity correction.
 p <- sales[,.(row_id,group,school_site_id,sale_year,price)]
 p[,`:=`(eta=as.numeric(fitted(log_fit)),exp_residual=exp(as.numeric(resid(log_fit))))]
 common_smear <- mean(p$exp_residual)
 pre_smear <- p[sale_year<=2012,.(factor=mean(exp_residual)),by=group]
 stopifnot(nrow(pre_smear)==2,!anyDuplicated(pre_smear$group))
 p[pre_smear,on="group",pre_group_smear:=i.factor]
 beta <- coef(log_fit)[grepl("sale_year::",names(coef(log_fit)))]
 beta_year <- as.integer(sub("sale_year::([0-9]+):treated","\\1",names(beta)))
 p[,event_term:=0]
 p[group=="Closed" & sale_year!=2012,event_term:=beta[match(sale_year,beta_year)]]
 p[,`:=`(predicted=exp(eta)*common_smear,predicted_no_event=exp(eta-event_term)*common_smear,
 predicted_pre_group=exp(eta)*pre_group_smear,predicted_pre_group_no_event=exp(eta-event_term)*pre_group_smear,controls=control_spec)]
 stopifnot(all(is.finite(p$predicted)),all(p$predicted>0),all(p[sale_year==2012 | group=="Stayed open",predicted==predicted_no_event]))
 predictions[[control_spec]] <- p
 smearing[[control_spec]] <- rbind(data.table(controls=control_spec,group="Pooled",period="2008-2018",factor=common_smear),pre_smear[,.(controls=control_spec,group,period="2008-2012",factor)])
 # Same additive levels regression, replacing observed price with each prediction.
 for(pred_name in c("predicted","predicted_no_event","predicted_pre_group","predicted_pre_group_no_event")) {
  sales[,y:=p[[pred_name]]]
  projected <- feols(event_formulas[[control_spec]],data=sales)
  terms <- names(coef(projected))[grepl("sale_year::",names(coef(projected)))]
  d <- data.table(controls=control_spec,prediction=pred_name,term=terms,sale_year=as.integer(sub("sale_year::([0-9]+):treated","\\1",terms)),estimate=unname(coef(projected)[terms]))
  # Linear projections decompose the observed coefficient into fitted plus residual pieces.
  sales[,y:=price-p[[pred_name]]]
  remainder <- feols(event_formulas[[control_spec]],data=sales)
  stopifnot(max(abs(coef(projected)[terms]+coef(remainder)[terms]-coef(levels_fit)[terms]))<1e-6)
  projections[[length(projections)+1L]] <- d
 }
}
coefficients <- rbindlist(coefficients)
model_support <- rbindlist(model_support)
predictions <- rbindlist(predictions)
smearing <- rbindlist(smearing)
projections <- rbindlist(projections)
annual <- predictions[,.(sales=.N,observed=mean(price),predicted=mean(predicted),predicted_no_event=mean(predicted_no_event),predicted_pre_group=mean(predicted_pre_group),predicted_pre_group_no_event=mean(predicted_pre_group_no_event),direct_event_dollars=mean(predicted-predicted_no_event)),by=.(controls,group,sale_year)]
annual_long <- melt(annual,id.vars=c("controls","group","sale_year","sales"),variable.name="series",value.name="mean_price")
gaps <- dcast(annual_long,controls+sale_year+series~group,value.var="mean_price")
gaps[,gap:=Closed-`Stayed open`]
gaps[,change_from_2012:=gap-gap[sale_year==2012],by=.(controls,series)]
# Compare post-period reconstruction errors to a flat 2012 gap or a zero event coefficient.
metrics <- list()
for(control_spec in c("without","with")) {
 for(pred_name in c("predicted","predicted_no_event","predicted_pre_group","predicted_pre_group_no_event")) {
  for(comparison in c("Raw mean gap change","Levels event coefficients")) {
   observed <- if(comparison=="Raw mean gap change") gaps[controls==control_spec & series=="observed" & sale_year>=2014,.(sale_year,observed=change_from_2012)] else coefficients[controls==control_spec & estimator=="OLS dollars" & design=="event" & sale_year>=2014,.(sale_year,observed=estimate)]
   predicted <- if(comparison=="Raw mean gap change") gaps[controls==control_spec & series==pred_name & sale_year>=2014,.(sale_year,predicted=change_from_2012)] else projections[controls==control_spec & prediction==pred_name & sale_year>=2014,.(sale_year,predicted=estimate)]
   d <- merge(observed,predicted,by="sale_year")
   stopifnot(nrow(d)==5L,!anyNA(d))
   metrics[[length(metrics)+1L]] <- data.table(controls=control_spec,prediction=pred_name,comparison=comparison,rmse=sqrt(mean((d$observed-d$predicted)^2)),zero_rmse=sqrt(mean(d$observed^2)),error_reduction=1-sum((d$observed-d$predicted)^2)/sum(d$observed^2),observed_2018=d[sale_year==2018,observed],predicted_2018=d[sale_year==2018,predicted])
  }
 }
}
metrics <- rbindlist(metrics)
setorder(coefficients,controls,estimator,design,sale_year);setorder(predictions,controls,row_id)
saveRDS(list(coefficients=coefficients,model_support=model_support,predictions=predictions,smearing=smearing,annual=annual,gaps=gaps,projections=projections,metrics=metrics),"../output/scale_checks.rds")
# Reports are written with the saved data, not separate Make targets.
writeLines(trimws(capture.output({
 cat("Saved RDS SHA-256:",digest::digest(file="../output/scale_checks.rds",algo="sha256"),"\n")
 report_data(coefficients,"coefficients",c("controls","estimator","design","term"))
 report_data(model_support,"model_support",c("controls","estimator","design"))
 report_data(predictions,"predictions",c("controls","row_id"))
 report_data(smearing,"smearing",c("controls","group","period"))
 report_data(annual,"annual",c("controls","group","sale_year"))
 report_data(gaps,"gaps",c("controls","sale_year","series"))
 report_data(projections,"projections",c("controls","prediction","term"))
 report_data(metrics,"metrics",c("controls","prediction","comparison"))
}),which="right"),"../report/scale_checks.txt")
print(coefficients[design=="did",.(controls,estimator,estimate,conf_low,conf_high)])
print(metrics)
print(smearing)
