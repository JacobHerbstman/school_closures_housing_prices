# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_hedonic_dynamics/code")
suppressPackageStartupMessages({library(data.table); library(fixest)})
source("../../../shared/code/report_data.R")
setFixest_nthreads(1)
baseline <- readRDS("../input/price_scales.rds")
overview <- readRDS("../input/overview.rds")

# Keep the preceding comparison's exact prices, transactions and site assignments.
sales <- baseline$predictions[controls=="with",.(row_id,group,school_site_id,sale_year,price)]
characteristics <- fread("../input/corrected_sales.csv",colClasses=c(row_id="character",pin="character"),
 select=c("row_id","pin","sale_date","sale_date_precision","res_char_bldg_sf","res_char_land_sf",
 "res_char_yrblt","res_char_beds","res_char_rooms","res_char_fbath","analysis_class",
 "res_char_type_resd","res_char_cnst_qlty","res_char_repair_cnd","hie_correction_eligible",
 "hie_start_year_timing_uncertain","res_char_renovation"))
# One transaction on each side. Every estimation row must match exactly once.
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(characteristics$row_id),
 all(sales$row_id %in% characteristics$row_id),
 overview$radius_miles==0.5,overview$property_sample=="single_family",overview$end_year==2018L)
sales <- merge(sales,characteristics,by="row_id",all.x=TRUE,sort=FALSE)
sales[,`:=`(treated=as.integer(group=="Closed"),log_price=log(price),
 log_building_sqft=log(res_char_bldg_sf),log_land_sqft=log(res_char_land_sf),
 age_at_sale=sale_year-res_char_yrblt,treated_post=as.integer(group=="Closed" & sale_year>=2014L))]
stopifnot(!anyDuplicated(sales$row_id),!anyNA(sales),all(nchar(sales$pin)==14),
 all(is.finite(sales$price) & sales$price>0),all(sales$age_at_sale>=0),
 uniqueN(sales$school_site_id)==68L,setequal(sales$sale_year,2008:2018))

# A repeat-sale parcel must sell in 2008-12 AND 2014-18. Retain all its transactions,
# including 2013 in annual events. Selection uses post-closure sales, so this is
# a selected population, not a correction for closure's effect on who sells.
parcel_support <- sales[,.(group=group[1],school_site_id=school_site_id[1],sales=.N,
 sale_years=uniqueN(sale_year),pre_sales=sum(sale_year<=2012),post_sales=sum(sale_year>=2014),
 transition_sales=sum(sale_year==2013),groups=uniqueN(group),sites=uniqueN(school_site_id),
 building_area_changed=uniqueN(res_char_bldg_sf)>1,year_built_changed=uniqueN(res_char_yrblt)>1,
 recorded_characteristics_changed=any(vapply(.SD,uniqueN,integer(1))>1L),
 improvement_record=any(hie_correction_eligible | res_char_renovation=="Yes"),
 uncertain_improvement_timing=any(hie_start_year_timing_uncertain)),by=pin,
 .SDcols=c("res_char_bldg_sf","res_char_land_sf","res_char_yrblt","res_char_beds","res_char_rooms",
 "res_char_fbath","analysis_class","res_char_type_resd","res_char_cnst_qlty","res_char_repair_cnd")]
stopifnot(!anyDuplicated(parcel_support$pin),all(parcel_support$groups==1L),all(parcel_support$sites==1L))
parcel_support[,repeat_pre_post:=pre_sales>0 & post_sales>0]
# Stable means no observed change or improvement flag; it does not certify no renovation.
parcel_support[,stable_repeat:=repeat_pre_post & !recorded_characteristics_changed & !improvement_record]
# Many transactions join to one parcel's support flags; the transaction count stays fixed.
sales[parcel_support,on="pin",`:=`(repeat_pre_post=i.repeat_pre_post,stable_repeat=i.stable_repeat)]
stopifnot(!anyNA(sales$repeat_pre_post),!anyNA(sales$stable_repeat),!anyDuplicated(sales$row_id))
parcel_summary <- parcel_support[,.(parcels=.N,repeat_any=sum(sales>=2),repeat_years=sum(sale_years>=2),
 repeat_pre_post=sum(repeat_pre_post),repeat_transactions=sum(sales[repeat_pre_post]),
 repeat_sites=uniqueN(school_site_id[repeat_pre_post]),stable_repeat=sum(stable_repeat),
 stable_transactions=sum(sales[stable_repeat]),stable_sites=uniqueN(school_site_id[stable_repeat]),
 repeat_area_changes=sum(repeat_pre_post & building_area_changed),
 repeat_year_built_changes=sum(repeat_pre_post & year_built_changed),
 repeat_characteristic_changes=sum(repeat_pre_post & recorded_characteristics_changed),
 repeat_improvement_records=sum(repeat_pre_post & improvement_record)),by=group]
site_support <- sales[,.(all_sales=.N,repeat_sales=sum(repeat_pre_post),repeat_parcels=uniqueN(pin[repeat_pre_post]),
 stable_sales=sum(stable_repeat),stable_parcels=uniqueN(pin[stable_repeat])),by=.(school_site_id,group)]
stopifnot(!anyDuplicated(overview$sites$school_site_id),all(site_support$school_site_id %in% overview$sites$school_site_id))
site_support <- merge(site_support,overview$sites[,.(school_site_id,school_names)],by="school_site_id",all.x=TRUE)
annual_support <- rbindlist(lapply(c("All sales","Repeat sales","Stable records"),function(sample_name) {
 d <- switch(sample_name,"All sales"=sales,"Repeat sales"=sales[repeat_pre_post==TRUE],"Stable records"=sales[stable_repeat==TRUE])
 d[,.(sales=.N,parcels=uniqueN(pin),sites=uniqueN(school_site_id),mean_price=mean(price)),
 by=.(group,sale_year)][,sample:=sample_name]
}))

# These are exactly the existing controls. The year-specific specification allows
# all their slopes/category premiums to vary, retaining the same site and year effects.
hedonics <- paste("log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2)",
 "+ age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath",
 "+ factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)")
comparisons <- c("All sales: fixed controls","All sales: controls by year","Repeat sales: site effects",
 "Repeat sales: parcel effects","Stable records: site effects","Stable records: parcel effects")
coefficients <- list(); models <- list(); dropped_terms <- list()
for(comparison in comparisons) {
 d <- copy(sales)
 if(grepl("^Repeat sales",comparison)) d <- d[repeat_pre_post==TRUE]
 if(grepl("^Stable records",comparison)) d <- d[stable_repeat==TRUE]
 effects <- if(grepl("parcel effects$",comparison)) "pin + sale_year" else "school_site_id + sale_year"
 control_terms <- if(comparison=="All sales: controls by year") paste0("factor(sale_year) * (",hedonics,")") else hedonics
 for(estimator in c("OLS dollars","OLS log","PPML")) {
  d[,y:=switch(estimator,"OLS dollars"=price,"OLS log"=log_price,PPML=price/1000)]
  for(design in c("event","did")) {
   # Pooled estimates always compare 2008-12 with 2014-18, omitting 2013.
   fit_data <- if(design=="event") d else d[sale_year!=2013L]
   treatment <- if(design=="event") "i(sale_year, treated, ref=2012)" else "treated_post"
   formula <- as.formula(paste("y ~",treatment,"+",control_terms,"|",effects))
   fit <- if(estimator=="PPML") fepois(formula,data=fit_data,vcov=~school_site_id,glm.iter=200,glm.tol=1e-10) else
    feols(formula,data=fit_data,vcov=~school_site_id)
   stopifnot(nobs(fit)==nrow(fit_data))
   if(estimator=="PPML") {
    stopifnot(isTRUE(fit$convStatus),all(is.finite(fitted(fit)) & fitted(fit)>0))
    # Fitted price totals must reproduce every included group-year indicator's score.
    score <- fit_data[,.(group,sale_year,post=sale_year>=2014,error=y-fitted(fit),total=y)]
    score <- if(design=="event") score[,.(relative_score=sum(error)/sum(total)),by=.(group,sale_year)] else
     score[,.(relative_score=sum(error)/sum(total)),by=.(group,post)]
    stopifnot(max(abs(score$relative_score))<1e-5)
   }
   b <- as.data.table(coeftable(fit),keep.rownames="term")
   setnames(b,c("term","estimate","std_error","statistic","p_value"))
   ci <- confint(fit)
   b[,`:=`(conf_low=ci[,1],conf_high=ci[,2])]
   b <- b[grepl("^sale_year::",term) | term=="treated_post"]
   stopifnot(nrow(b)==if(design=="event") 10L else 1L,all(is.finite(b$std_error)))
   b[,sale_year:=if(design=="event") as.integer(sub("sale_year::([0-9]+):treated","\\1",term)) else NA_integer_]
   if(comparison=="All sales: fixed controls") {
    current_estimator <- estimator; current_design <- design
    expected <- baseline$coefficients[controls=="with" & estimator==current_estimator & design==current_design]
    stopifnot(setequal(expected$term,b$term),max(abs(expected$estimate-b$estimate[match(expected$term,b$term)]))<1e-6,
     max(abs(expected$std_error-b$std_error[match(expected$term,b$term)]))<1e-6)
   }
   b[,`:=`(comparison=comparison,estimator=estimator,design=design)]
   coefficients[[length(coefficients)+1L]] <- b
   pretrend_p <- NA_real_
   if(design=="event") {
    pre_test <- wald(fit,keep="^sale_year::200[89]:treated$|^sale_year::201[01]:treated$",print=FALSE)
    stopifnot(is.finite(pre_test$stat),pre_test$df1==4)
    pretrend_p <- pf(pre_test$stat,4,uniqueN(fit_data$school_site_id)-1L,lower.tail=FALSE)
   }
   models[[length(models)+1L]] <- data.table(comparison,estimator,design,observations=nobs(fit),
    parcels=uniqueN(fit_data$pin),sites=uniqueN(fit_data$school_site_id),treated_sales=sum(fit_data$treated),
    control_sales=sum(fit_data$treated==0),treated_parcels=uniqueN(fit_data[treated==1,pin]),
    control_parcels=uniqueN(fit_data[treated==0,pin]),treated_sites=uniqueN(fit_data[treated==1,school_site_id]),
    control_sites=uniqueN(fit_data[treated==0,school_site_id]),pretrend_p=pretrend_p,
    estimated_slopes=length(coef(fit)),collinear_terms=length(fit$collin.var),fixest_version=as.character(packageVersion("fixest")))
   if(length(fit$collin.var)) dropped_terms[[length(dropped_terms)+1L]] <- data.table(comparison,estimator,design,term=fit$collin.var)
  }
 }
}
coefficients <- rbindlist(coefficients); models <- rbindlist(models); dropped_terms <- rbindlist(dropped_terms)
stopifnot(nrow(models)==36L)
setorder(sales,row_id);setorder(parcel_support,pin);setorder(parcel_summary,group)
setorder(annual_support,sample,group,sale_year);setorder(site_support,group,school_site_id)
setorder(coefficients,comparison,estimator,design,sale_year);setorder(models,comparison,estimator,design)
setorder(dropped_terms,comparison,estimator,design,term)
sources <- data.table(source=c("../input/price_scales.rds","../input/overview.rds","../input/corrected_sales.csv"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
saveRDS(list(sales=sales,parcel_support=parcel_support,parcel_summary=parcel_summary,site_support=site_support,
 annual_support=annual_support,coefficients=coefficients,models=models,dropped_terms=dropped_terms,sources=sources),
 "../output/hedonic_dynamics.rds")
writeLines(trimws(capture.output({
 cat("Saved RDS SHA-256:",digest::digest(file="../output/hedonic_dynamics.rds",algo="sha256"),"\n")
 report_data(sales,"sales","row_id")
 report_data(parcel_support,"parcel_support","pin")
 report_data(parcel_summary,"parcel_summary","group")
 report_data(site_support,"site_support","school_site_id")
 report_data(annual_support,"annual_support",c("sample","group","sale_year"))
 report_data(coefficients,"coefficients",c("comparison","estimator","design","term"))
 report_data(models,"models",c("comparison","estimator","design"))
 report_data(dropped_terms,"dropped_terms",c("comparison","estimator","design","term"))
 report_data(sources,"sources","source")
}),which="right"),"../report/hedonic_dynamics.txt")
print(parcel_summary)
print(coefficients[design=="did",.(comparison,estimator,estimate,conf_low,conf_high)])
print(models[design=="event",.(comparison,estimator,observations,parcels,sites,pretrend_p)])
