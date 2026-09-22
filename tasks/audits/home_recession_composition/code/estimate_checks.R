# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_recession_composition/code")
suppressPackageStartupMessages({library(data.table);library(fixest)})
source("../../../shared/code/report_data.R")
setFixest_nthreads(1)
a <- readRDS("../output/composition.rds")
previous <- readRDS("../input/assessments.rds")
sales <- a$sales
hedonics <- paste("log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2)",
 "+ age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath",
 "+ factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)")
comparisons <- c("Existing model","Seller types by year","Known non-bank sellers","Initial value by year",
 "2012 omitted","Common sites: transaction weights","Common sites: fixed site shares")
events <- list();contrasts <- list();models <- list();dropped_terms <- list()
for(comparison in comparisons) {
 d <- copy(sales);control_terms <- hedonics
 if(comparison=="Seller types by year") control_terms <- paste(hedonics,"+ factor(seller_type) * factor(sale_year)")
 if(comparison=="Known non-bank sellers") d <- d[seller_known==TRUE & broad_seller==FALSE]
 if(comparison=="Initial value by year") {
  d <- d[assessment_usable==TRUE]
  control_terms <- paste(hedonics,"+ log_initial_value * factor(sale_year)")
 }
 if(comparison=="2012 omitted") d <- d[sale_year!=2012]
 if(grepl("^Common sites",comparison)) d <- d[assessment_usable==TRUE & sale_year<=2013 & school_site_id %in% a$common_sites$school_site_id]
 d[,weight:=1]
 if(comparison=="Common sites: fixed site shares") {
  # Same six-year sample as the preceding model. Fix site shares within each
  # group, preserving each group's actual number of sales in every year.
  d <- merge(d,a$fixed_weights[,.(group,school_site_id,site_weight)],by=c("group","school_site_id"),all.x=TRUE)
  d[,weight:=site_weight/.N,by=.(group,school_site_id,sale_year)]
  d[,weight:=weight*.N,by=.(group,sale_year)]
  stopifnot(d[,all(abs(sum(weight)-.N)<1e-8),by=.(group,sale_year)]$V1)
 }
 formula <- as.formula(paste("log_price ~ i(sale_year,treated,ref=2008) +",control_terms,"| school_site_id + sale_year"))
 fit <- feols(formula,data=d,weights=~weight,vcov=~school_site_id)
 stopifnot(nobs(fit)==nrow(d),all(is.finite(coef(fit))))
 b <- coef(fit);v <- vcov(fit);critical <- qt(.975,uniqueN(d$school_site_id)-1)
 # Build differences from the full covariance matrix. Rebasing changes the
 # origin and individual intervals, not fitted values or pre-period equality.
 for(reference in intersect(c(2008L,2012L),unique(d$sale_year))) {
  for(year in sort(unique(d$sale_year))) {
   contrast <- setNames(rep(0,length(b)),names(b))
   if(year!=2008L) contrast[paste0("sale_year::",year,":treated")] <- contrast[paste0("sale_year::",year,":treated")]+1
   if(reference!=2008L) contrast[paste0("sale_year::",reference,":treated")] <- contrast[paste0("sale_year::",reference,":treated")]-1
   estimate <- sum(contrast*b);se <- sqrt(max(0,as.numeric(t(contrast)%*%v%*%contrast)))
   events[[length(events)+1L]] <- data.table(comparison,reference,sale_year=year,estimate,std_error=se,
    conf_low=estimate-critical*se,conf_high=estimate+critical*se)
  }
 }
 for(pair in list(c(2010L,2008L),c(2012L,2010L),c(2012L,2011L))) {
  if(!all(pair %in% d$sale_year)) next
  contrast <- setNames(rep(0,length(b)),names(b))
  if(pair[1]!=2008L) contrast[paste0("sale_year::",pair[1],":treated")] <- 1
  if(pair[2]!=2008L) contrast[paste0("sale_year::",pair[2],":treated")] <- -1
  estimate <- sum(contrast*b);se <- sqrt(as.numeric(t(contrast)%*%v%*%contrast))
  contrasts[[length(contrasts)+1L]] <- data.table(comparison,from_year=pair[2],to_year=pair[1],estimate,
   std_error=se,conf_low=estimate-critical*se,conf_high=estimate+critical*se)
 }
 pre <- wald(fit,keep="^sale_year::2009:treated$|^sale_year::201[012]:treated$",print=FALSE)
 pretrend_p <- pf(pre$stat,pre$df1,uniqueN(d$school_site_id)-1,lower.tail=FALSE)
 models[[length(models)+1L]] <- data.table(comparison,sales=nobs(fit),sites=uniqueN(d$school_site_id),
  treated_sales=sum(d$treated),control_sales=sum(d$treated==0),start_year=min(d$sale_year),end_year=max(d$sale_year),
  pretrend_p,pre_df=pre$df1,formula=paste(deparse(formula),collapse=" "))
 if(length(fit$collin.var)) dropped_terms[[length(dropped_terms)+1L]] <- data.table(comparison,term=fit$collin.var)
}
events <- rbindlist(events);contrasts <- rbindlist(contrasts);models <- rbindlist(models);dropped_terms <- rbindlist(dropped_terms)
for(comparison in c("Existing model","Initial value by year")) {
 old_name <- if(comparison=="Existing model") "All sales: existing model" else "Matched: initial value by year"
 old <- previous$coefficients[comparison==old_name & estimator=="OLS log" & design=="event"]
 target_comparison <- comparison
 current <- events[comparison==target_comparison & reference==2012 & sale_year!=2012]
 stopifnot(max(abs(old$estimate-current$estimate[match(old$sale_year,current$sale_year)]))<1e-8,
  max(abs(old$std_error-current$std_error[match(old$sale_year,current$sale_year)]))<1e-8)
}

# Omit every school site, including controls, one at a time. Report all results
# rather than selecting an exclusion that makes the pre-period pattern disappear.
omissions <- list()
for(site in sort(unique(sales$school_site_id))) {
 d <- sales[school_site_id!=site]
 fit <- feols(as.formula(paste("log_price ~ i(sale_year,treated,ref=2012) +",hedonics,"| school_site_id + sale_year")),
  data=d,vcov=~school_site_id,notes=FALSE)
 term <- "sale_year::2010:treated"
 ci <- confint(fit,parm=term)
 omissions[[length(omissions)+1L]] <- data.table(school_site_id=site,school_names=sales[school_site_id==site,school_names][1],
  group=sales[school_site_id==site,group][1],omitted_sales=sum(sales$school_site_id==site),observations=nobs(fit),
  estimate=coef(fit)[term],std_error=se(fit)[term],conf_low=ci[1,1],conf_high=ci[1,2])
 stopifnot(nobs(fit)==nrow(d),is.finite(coef(fit)[term]))
}
omissions <- rbindlist(omissions)
setorder(events,comparison,reference,sale_year);setorder(contrasts,comparison,from_year,to_year)
setorder(models,comparison);setorder(omissions,group,school_site_id);setorder(dropped_terms,comparison,term)
sources <- data.table(source=c("../output/composition.rds","../input/assessments.rds"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
saveRDS(list(events=events,contrasts=contrasts,models=models,omissions=omissions,dropped_terms=dropped_terms,sources=sources),"../output/model_checks.rds")
writeLines(trimws(capture.output({
 cat("RDS SHA-256:",digest::digest(file="../output/model_checks.rds",algo="sha256"),"\n")
 report_data(events,"events",c("comparison","reference","sale_year"))
 report_data(contrasts,"contrasts",c("comparison","from_year","to_year"))
 report_data(models,"models","comparison")
 report_data(omissions,"omissions","school_site_id")
 report_data(dropped_terms,"dropped_terms",c("comparison","term"))
 report_data(sources,"sources","source")
}),which="right"),"../report/model_checks.txt")
print(models[,.(comparison,sales,sites,start_year,end_year,pretrend_p)])
print(contrasts[,.(comparison,from_year,to_year,percent=100*expm1(estimate),low=100*expm1(conf_low),high=100*expm1(conf_high))])
print(omissions[,.(min_percent=min(100*expm1(estimate)),max_percent=max(100*expm1(estimate)),count=.N),by=group])
