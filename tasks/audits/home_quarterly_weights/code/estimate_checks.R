# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_quarterly_weights/code")
suppressPackageStartupMessages({library(data.table); library(fixest)})
source("../../../shared/code/report_data.R")
baseline <- readRDS("../input/price_scales.rds")
overview <- readRDS("../input/overview.rds")
timeline <- fread("timeline.csv")
# Reuse the exact common estimation sample, real prices and school assignments
# from the preceding log/levels/PPML comparison. There is no new price cleaning.
sales <- baseline$predictions[controls=="with",.(row_id,group,school_site_id,sale_year,price)]
characteristics <- fread("../input/corrected_sales.csv",colClasses=c(row_id="character"),
 select=c("row_id","sale_month","sale_quarter","sale_date_precision","is_mydec_date",
 "res_char_bldg_sf","res_char_land_sf","res_char_yrblt","res_char_beds","res_char_rooms","res_char_fbath",
 "analysis_class","res_char_type_resd","res_char_cnst_qlty","res_char_repair_cnd"))
# One row per transaction on each side; every estimation row must match.
stopifnot(!anyNA(sales$row_id),!anyDuplicated(sales$row_id),!anyDuplicated(characteristics$row_id),
 all(sales$row_id %in% characteristics$row_id),
 overview$radius_miles==0.5,overview$property_sample=="single_family",overview$end_year==2018L)
sales <- merge(sales,characteristics,by="row_id",all.x=TRUE,sort=FALSE)
sales[,`:=`(treated=as.integer(group=="Closed"),log_price=log(price),
 log_building_sqft=log(res_char_bldg_sf),log_land_sqft=log(res_char_land_sf),age_at_sale=sale_year-res_char_yrblt,
 quarter_id=(sale_year-2008L)*4L+sale_quarter,treated_post=as.integer(group=="Closed" & sale_year>=2014L))]
stopifnot(!anyDuplicated(sales$row_id),!anyNA(sales),all(is.finite(sales$price) & sales$price>0),
 all(sales$analysis_class %in% c(202:210,234,278,295)),all(sales$age_at_sale>=0),
 all(sales$sale_quarter==(sales$sale_month-1L)%/%3L+1L))
sites <- sales[,.(sales=.N,pre_sales=sum(sale_year<=2012L),mean_price=mean(price)),by=.(school_site_id,group)]
# School-site names are unique in the supplied packet roster.
stopifnot(!anyDuplicated(overview$sites$school_site_id),all(sites$school_site_id %in% overview$sites$school_site_id))
sites <- merge(sites,overview$sites[,.(school_site_id,school_names)],by="school_site_id",all.x=TRUE)
setorder(sites,group,-sales,school_site_id)
sites[,volume_rank:=seq_len(.N),by=group]
top_three <- sites[group=="Closed" & volume_rank<=3L,school_site_id]
pre_top_three <- sites[group=="Closed"][order(-pre_sales,school_site_id)][1:3,school_site_id]
stopifnot(length(top_three)==3L,setequal(top_three,pre_top_three))
sites[,dropped:=school_site_id %in% top_three]
date_support <- sales[,.(sales=.N,refined_dates=sum(is_mydec_date)),by=.(group,sale_year,sale_quarter,quarter_id)]
date_support[,refined_share:=refined_dates/sales]

# The quarterly reference (2012 Q3) precedes the December utilization list.
# Annual models retain the previous 2012 reference for direct comparison.
event_formulas <- list(
 without=y ~ i(period,treated,ref=reference_period) | school_site_id+period,
 with=y ~ i(period,treated,ref=reference_period)+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+period)
did_formulas <- list(
 without=y ~ treated_post | school_site_id+period,
 with=y ~ treated_post+log_building_sqft+I(log_building_sqft^2)+log_land_sqft+I(log_land_sqft^2)+age_at_sale+I(age_at_sale^2)+res_char_beds+res_char_rooms+res_char_fbath+factor(analysis_class)+factor(res_char_type_resd)+factor(res_char_cnst_qlty)+factor(res_char_repair_cnd) | school_site_id+period)
coefficients <- list(); models <- list(); changes <- list(); raw <- list(); support <- list()
for(frequency in c("Annual","Quarterly")) {
 reference_period <- if(frequency=="Annual") 2012L else 19L
 for(comparison in c("Transactions","Equal sites","Drop top three")) {
  d <- copy(sales)
  if(comparison=="Drop top three") d <- d[!school_site_id %in% top_three]
  d[,period:=if(frequency=="Annual") sale_year else quarter_id]
  d[,weight:=if(comparison=="Equal sites") 1/.N else 1,by=.(school_site_id,period)]
  observed <- d[,.(sales=.N,weight_sum=sum(weight)),by=.(school_site_id,group,period)]
  stopifnot(!anyDuplicated(observed[,.(school_site_id,period)]))
  if(comparison=="Equal sites") stopifnot(max(abs(observed$weight_sum-1))<1e-10)
  # Full grid records empty cells; no price is imputed for a site without sales.
  grid <- CJ(school_site_id=unique(d$school_site_id),period=sort(unique(d$period)))
  grid[,group:=sites$group[match(school_site_id,sites$school_site_id)]]
  grid <- merge(grid,observed,by=c("school_site_id","group","period"),all.x=TRUE)
  grid[is.na(sales),`:=`(sales=0L,weight_sum=0)]
  grid[,`:=`(frequency=frequency,comparison=comparison)]
  support[[length(support)+1L]] <- grid
  raw[[length(raw)+1L]] <- d[,.(sales=.N,sites=uniqueN(school_site_id),mean_price=weighted.mean(price,weight),
   mean_log_price=weighted.mean(log_price,weight)),by=.(group,period)][,`:=`(frequency=frequency,comparison=comparison)]
  for(control_spec in names(event_formulas)) {
   for(estimator in c("OLS dollars","OLS log","PPML")) {
    d[,y:=switch(estimator,"OLS dollars"=price,"OLS log"=log_price,PPML=price/1000)]
    for(design in c("event","did")) {
     # Retain every 2013 quarter in events; the pooled summary remains 2008-12 versus 2014-18.
     fit_data <- if(design=="event") d else d[sale_year!=2013L]
     formula <- if(design=="event") event_formulas[[control_spec]] else did_formulas[[control_spec]]
     fit <- if(estimator=="PPML") fepois(formula,data=fit_data,weights=~weight,vcov=~school_site_id,
      glm.iter=100,glm.tol=1e-10) else feols(formula,data=fit_data,weights=~weight,vcov=~school_site_id)
     stopifnot(nobs(fit)==nrow(fit_data))
     if(estimator=="PPML") {
      stopifnot(isTRUE(fit$convStatus),all(is.finite(fitted(fit)) & fitted(fit)>0))
      if(design=="event") {
       score <- fit_data[,.(group,period,error=weight*(y-fitted(fit)),total=weight*y)][,
        .(relative_score=sum(error)/sum(total)),by=.(group,period)]
       stopifnot(max(abs(score$relative_score))<1e-5)
      }
     }
     b <- as.data.table(coeftable(fit),keep.rownames="term")
     setnames(b,c("term","estimate","std_error","statistic","p_value"))
     ci <- confint(fit)
     b[,`:=`(conf_low=ci[,1],conf_high=ci[,2])]
     b <- b[grepl("^period::",term) | term=="treated_post"]
     b[,period:=if(design=="event") as.integer(sub("period::([0-9]+):treated","\\1",term)) else NA_integer_]
     if(design=="event") stopifnot(setequal(b$period,setdiff(unique(d$period),reference_period)))
     if(frequency=="Annual" & comparison=="Transactions") {
      current_estimator <- estimator
      current_design <- design
      expected <- copy(baseline$coefficients[controls==control_spec & estimator==current_estimator & design==current_design])
      # Match the old event terms after the time-variable rename.
      expected[,new_term:=sub("sale_year::","period::",term,fixed=TRUE)]
      stopifnot(nrow(expected)==nrow(b),setequal(expected$new_term,b$term),
       max(abs(expected$estimate-b$estimate[match(expected$new_term,b$term)]))<1e-6)
     }
     b[,`:=`(frequency=frequency,comparison=comparison,controls=control_spec,estimator=estimator,design=design)]
     coefficients[[length(coefficients)+1L]] <- b
     pretrend_p <- NA_real_
     if(design=="event") {
      pre_terms <- b[period<reference_period,term]
      pre_test <- wald(fit,keep=paste0("^(",paste(pre_terms,collapse="|"),")$"),print=FALSE)
      stopifnot(is.finite(pre_test$stat))
      pretrend_p <- pf(pre_test$stat,pre_test$df1,uniqueN(fit_data$school_site_id)-1L,lower.tail=FALSE)
     }
     models[[length(models)+1L]] <- data.table(frequency,comparison,controls=control_spec,estimator,design,
      observations=nobs(fit),sites=uniqueN(fit_data$school_site_id),treated_sales=sum(fit_data$treated),
      control_sales=sum(fit_data$treated==0),reference_period=if(design=="event") reference_period else NA_integer_,
      pretrend_p=pretrend_p,fixest_version=as.character(packageVersion("fixest")))
     if(frequency=="Quarterly" & design=="event") {
      # Differences of adjacent event coefficients use their full clustered covariance.
      for(to_period in 20:24) {
       contrast <- setNames(rep(0,length(coef(fit))),names(coef(fit)))
       contrast[paste0("period::",to_period,":treated")] <- 1
       if(to_period-1L!=reference_period) contrast[paste0("period::",to_period-1L,":treated")] <- -1
       stopifnot(length(contrast)==length(coef(fit)))
       estimate <- sum(contrast*coef(fit))
       se <- sqrt(as.numeric(t(contrast)%*%vcov(fit)%*%contrast))
       df <- uniqueN(fit_data$school_site_id)-1L
       changes[[length(changes)+1L]] <- data.table(comparison,controls=control_spec,estimator,
        from_period=to_period-1L,to_period,estimate,std_error=se,
        conf_low=estimate-qt(.975,df)*se,conf_high=estimate+qt(.975,df)*se,
        p_value=2*pt(abs(estimate/se),df,lower.tail=FALSE),df=df)
      }
     }
    }
   }
  }
 }
}
coefficients <- rbindlist(coefficients); models <- rbindlist(models); changes <- rbindlist(changes)
raw <- rbindlist(raw); support <- rbindlist(support)
stopifnot(nrow(models)==72L,nrow(changes)==90L)
setorder(coefficients,frequency,comparison,controls,estimator,design,period)
setorder(models,frequency,comparison,controls,estimator,design)
setorder(raw,frequency,comparison,group,period); setorder(support,frequency,comparison,school_site_id,period)
sources <- data.table(source=c("../input/price_scales.rds","../input/overview.rds","../input/corrected_sales.csv","timeline.csv"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
saveRDS(list(coefficients=coefficients,models=models,changes=changes,raw=raw,support=support,sites=sites,
 date_support=date_support,timeline=timeline,sources=sources),"../output/quarterly_weights.rds")
writeLines(trimws(capture.output({
 cat("Saved RDS SHA-256:",digest::digest(file="../output/quarterly_weights.rds",algo="sha256"),"\n")
 report_data(coefficients,"coefficients",c("frequency","comparison","controls","estimator","design","term"))
 report_data(models,"models",c("frequency","comparison","controls","estimator","design"))
 report_data(changes,"changes",c("comparison","controls","estimator","to_period"))
 report_data(raw,"raw",c("frequency","comparison","group","period"))
 report_data(support,"support",c("frequency","comparison","school_site_id","period"))
 report_data(sites,"sites","school_site_id")
 report_data(date_support,"date_support",c("group","quarter_id"))
 report_data(timeline,"timeline","event")
 report_data(sources,"sources","source")
}),which="right"),"../report/quarterly_weights.txt")
print(sites[dropped==TRUE])
print(coefficients[frequency=="Annual" & design=="did" & controls=="with",.(comparison,estimator,estimate,conf_low,conf_high)])
print(changes[controls=="with"])
