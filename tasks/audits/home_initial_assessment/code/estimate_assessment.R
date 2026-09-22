# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_initial_assessment/code")
suppressPackageStartupMessages({library(data.table);library(jsonlite);library(fixest)})
source("../../../shared/code/report_data.R")
setFixest_nthreads(1)
baseline <- readRDS("../input/hedonic_dynamics.rds")
sales <- copy(baseline$sales)
stopifnot(!anyDuplicated(sales$row_id))

extract_dir <- tempfile("assessment_extract_",tmpdir="../temp")
dir.create(extract_dir)
members <- untar("../output/assessments_2006_snapshot.tar.gz",list=TRUE)
stopifnot(all(members==basename(members)),all(c("queries.csv","requested_pins.csv","metadata.json","source.json") %in% members))
untar("../output/assessments_2006_snapshot.tar.gz",exdir=extract_dir)
queries <- fread(file.path(extract_dir,"queries.csv"))
requested <- fread(file.path(extract_dir,"requested_pins.csv"),colClasses=c(pin="character"))
stopifnot(setequal(requested$pin,sales$pin),!anyDuplicated(requested$pin),!anyDuplicated(queries$filename))
for(i in seq_len(nrow(queries))) stopifnot(digest::digest(file=file.path(extract_dir,queries$filename[i]),algo="sha256")==queries$sha256[i])
assessments <- rbindlist(lapply(queries$filename,function(filename) as.data.table(fromJSON(file.path(extract_dir,filename)))),fill=TRUE)
metadata <- fromJSON(file.path(extract_dir,"metadata.json"))
source_info <- fromJSON(file.path(extract_dir,"source.json"))
stopifnot(digest::digest(file=file.path(extract_dir,"metadata.json"),algo="sha256")==source_info$metadata_sha256)
numeric_columns <- intersect(metadata$columns$fieldName[metadata$columns$dataTypeName=="number"],names(assessments))
assessments[,(numeric_columns):=lapply(.SD,as.numeric),.SDcols=numeric_columns]
stopifnot(!anyDuplicated(assessments$pin),!anyDuplicated(assessments$row_id),all(assessments$year==2006L),
 all(assessments$pin %in% requested$pin),nrow(assessments)==sum(queries$received_rows),
 all(assessments$mailed_tot==assessments$mailed_bldg+assessments$mailed_land,na.rm=TRUE))

# Many transactions join to one 2006 assessment per PIN. Keep unmatched rows to
# measure coverage; never replace a missing initial value with a later assessment.
initial <- assessments[,.(pin,assessment_year=year,assessment_class=class,assessment_row_id=row_id,
 initial_assessed_total=mailed_tot,initial_assessed_building=mailed_bldg,initial_assessed_land=mailed_land)]
sales <- merge(sales,initial,by="pin",all.x=TRUE,sort=FALSE)
stopifnot(nrow(sales)==nrow(baseline$sales),!anyDuplicated(sales$row_id),
 identical(sales$price,baseline$sales$price[match(sales$row_id,baseline$sales$row_id)]))
sales[,assessment_status:=fcase(is.na(assessment_row_id),"No 2006 record",
 !is.finite(initial_assessed_total) | initial_assessed_total<=0,"No positive total",
 !assessment_class %in% as.character(c(202:210,234,278,295)),"Not single-family in 2006",
 !is.finite(initial_assessed_building) | initial_assessed_building<=0,"No positive building value",
 default="Usable 2006 assessment")]
sales[,assessment_usable:=assessment_status=="Usable 2006 assessment"]
# Use the same positive residential structure definition in both groups. Land-only
# or converted properties lack a comparable initial house value and are reported.
sales[assessment_usable==TRUE,log_initial_value:=log(initial_assessed_total)]
stopifnot(all(is.finite(sales[assessment_usable==TRUE,log_initial_value])),
 sales[group=="Closed",mean(assessment_usable)]>.8,sales[group=="Stayed open",mean(assessment_usable)]>.8)
parcels <- unique(sales[,.(pin,group,school_site_id,assessment_status,assessment_usable,
 assessment_class,initial_assessed_total,initial_assessed_building,initial_assessed_land)])
stopifnot(!anyDuplicated(parcels$pin))
coverage <- sales[,.(sales=.N,parcels=uniqueN(pin),sites=uniqueN(school_site_id)),by=.(group,assessment_status)]
annual_support <- sales[,.(all_sales=.N,matched_sales=sum(assessment_usable),
 matched_share=mean(assessment_usable),mean_initial_value=mean(initial_assessed_total[assessment_usable]),
 median_initial_value=median(initial_assessed_total[assessment_usable])),by=.(group,sale_year)]
initial_distribution <- parcels[assessment_usable==TRUE,.(parcels=.N,mean=mean(initial_assessed_total),
 p10=quantile(initial_assessed_total,.1),median=median(initial_assessed_total),p90=quantile(initial_assessed_total,.9)),by=group]

# Existing hedonics, sites, years, deflator and transaction weights are unchanged.
# A constant initial-value coefficient adjusts levels. Interacting its log with
# year allows different crisis/recovery paths across initially valued properties.
hedonics <- paste("log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2)",
 "+ age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath",
 "+ factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)")
comparisons <- c("All sales: existing model","Matched: existing model","Matched: initial value",
 "Matched: initial value by year","Matched: all premiums by year")
coefficients <- list(); models <- list(); dropped_terms <- list()
for(comparison in comparisons) {
 d <- if(comparison=="All sales: existing model") copy(sales) else sales[assessment_usable==TRUE]
 control_terms <- switch(comparison,
  "All sales: existing model"=hedonics,"Matched: existing model"=hedonics,
  "Matched: initial value"=paste(hedonics,"+ log_initial_value"),
  "Matched: initial value by year"=paste(hedonics,"+ factor(sale_year) * log_initial_value"),
  "Matched: all premiums by year"=paste0("factor(sale_year) * (",hedonics,"+ log_initial_value)"))
 for(estimator in c("OLS dollars","OLS log","PPML")) {
  d[,y:=switch(estimator,"OLS dollars"=price,"OLS log"=log_price,PPML=price/1000)]
  for(design in c("event","did")) {
   fit_data <- if(design=="event") d else d[sale_year!=2013L]
   treatment <- if(design=="event") "i(sale_year, treated, ref=2012)" else "treated_post"
   formula <- as.formula(paste("y ~",treatment,"+",control_terms,"| school_site_id + sale_year"))
   fit <- if(estimator=="PPML") fepois(formula,data=fit_data,vcov=~school_site_id,glm.iter=200,glm.tol=1e-10) else
    feols(formula,data=fit_data,vcov=~school_site_id)
   stopifnot(nobs(fit)==nrow(fit_data))
   if(estimator=="PPML") {
    stopifnot(isTRUE(fit$convStatus),all(is.finite(fitted(fit)) & fitted(fit)>0))
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
   if(comparison=="All sales: existing model") {
    current_estimator <- estimator;current_design <- design
    expected <- baseline$coefficients[comparison=="All sales: fixed controls" & estimator==current_estimator & design==current_design]
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
    control_sales=sum(fit_data$treated==0),treated_sites=uniqueN(fit_data[treated==1,school_site_id]),
    control_sites=uniqueN(fit_data[treated==0,school_site_id]),pretrend_p,
    estimated_slopes=length(coef(fit)),formula=paste(deparse(formula),collapse=" "),
    fixest_version=as.character(packageVersion("fixest")))
   if(length(fit$collin.var)) dropped_terms[[length(dropped_terms)+1L]] <- data.table(comparison,estimator,design,term=fit$collin.var)
  }
 }
}
coefficients <- rbindlist(coefficients);models <- rbindlist(models);dropped_terms <- rbindlist(dropped_terms)
stopifnot(nrow(models)==30L)
setorder(sales,row_id);setorder(parcels,pin);setorder(assessments,pin)
setorder(coverage,group,assessment_status);setorder(annual_support,group,sale_year);setorder(initial_distribution,group)
setorder(coefficients,comparison,estimator,design,sale_year);setorder(models,comparison,estimator,design)
setorder(dropped_terms,comparison,estimator,design,term)
sources <- data.table(source=c("../input/hedonic_dynamics.rds","../output/assessments_2006_snapshot.tar.gz"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
saveRDS(list(sales=sales,parcels=parcels,assessments=assessments,coverage=coverage,annual_support=annual_support,
 initial_distribution=initial_distribution,coefficients=coefficients,models=models,dropped_terms=dropped_terms,
 sources=sources,source_info=source_info),"../output/initial_assessment.rds")
writeLines(trimws(capture.output({
 cat("Saved RDS SHA-256:",digest::digest(file="../output/initial_assessment.rds",algo="sha256"),"\n")
 report_data(sales,"sales","row_id")
 report_data(parcels,"parcels","pin")
 report_data(assessments,"assessments",c("pin","year"))
 report_data(coverage,"coverage",c("group","assessment_status"))
 report_data(annual_support,"annual_support",c("group","sale_year"))
 report_data(initial_distribution,"initial_distribution","group")
 report_data(coefficients,"coefficients",c("comparison","estimator","design","term"))
 report_data(models,"models",c("comparison","estimator","design"))
 report_data(dropped_terms,"dropped_terms",c("comparison","estimator","design","term"))
 report_data(sources,"sources","source")
}),which="right"),"../report/initial_assessment.txt")
print(coverage);print(initial_distribution)
print(coefficients[design=="did",.(comparison,estimator,estimate,conf_low,conf_high)])
print(coefficients[design=="event" & sale_year==2010,.(comparison,estimator,estimate,conf_low,conf_high)])
print(models[design=="event",.(comparison,estimator,observations,sites,pretrend_p)])
