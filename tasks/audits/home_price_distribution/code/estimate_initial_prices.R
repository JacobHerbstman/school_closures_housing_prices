# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
suppressPackageStartupMessages({library(data.table);library(fixest)})
sales <- fread("../output/analysis_sample.csv",colClasses=c(row_id="character",pin="character"))
baseline <- fread("../input/baseline_coefficients.csv")
stopifnot(!anyDuplicated(sales$row_id),!anyDuplicated(baseline[,.(model,term)]))
# The initial price is fixed at each physical site's pooled pre-closure mean.
sites <- sales[sale_year<=2012,.(treated=treated[1],school_names=school_names[1],
  pre_sales=.N,pre_parcels=uniqueN(pin),pre_years=uniqueN(sale_year),
  initial_price=mean(sale_price_real_2022),pre_price_sd=sd(sale_price_real_2022)),by=school_site_id]
stopifnot(nrow(sites)==77,!anyDuplicated(sites$school_site_id),!anyNA(sites[,.(treated,school_names,pre_sales,initial_price)]),
  all(is.na(sites$pre_price_sd)==(sites$pre_sales==1L)),
  all(sales$school_site_id %in% sites$school_site_id))
# Many transactions join to one site-level pre-treatment covariate.
sales <- merge(sales,sites[,.(school_site_id,initial_price)],by="school_site_id",all.x=TRUE)
stopifnot(nrow(sales)==10921,!anyNA(sales$initial_price),!anyDuplicated(sales$row_id))
sales[, `:=`(initial_price_100k=initial_price/100000,treated_post=treated*as.integer(sale_year>=2014))]
coefficients <- list()
models <- list()
index <- 0L
for(design in c("did","event")) for(hedonic in c(FALSE,TRUE)) for(adjusted in c(FALSE,TRUE)) for(outcome in c("dollars","log")) {
  index <- index+1L
  d <- if(design=="did") sales[sale_year!=2013] else copy(sales)
  model_name <- paste0(design,if(hedonic) "_hedonic" else "","_",outcome)
  formula_text <- paste0(if(outcome=="log") "log_real_price ~ " else "sale_price_real_2022 ~ ",if(design=="did") "treated_post" else "i(sale_year, treated, ref=2012)",
    if(adjusted) " + i(sale_year, initial_price_100k, ref=2012)" else "",
    if(hedonic) paste0(" + log_building_sqft + I(log_building_sqft^2) + log_land_sqft + I(log_land_sqft^2)",
      " + age_at_sale + I(age_at_sale^2) + res_char_beds + res_char_rooms + res_char_fbath + apartments",
      " + factor(analysis_class) + factor(res_char_type_resd) + factor(res_char_cnst_qlty) + factor(res_char_repair_cnd)") else "",
    " | school_site_id + sale_year")
  fit <- feols(as.formula(formula_text),data=d,vcov=~school_site_id,nthreads=1,notes=FALSE)
  # The split-level category is redundant with property class in the baseline too.
  stopifnot(nobs(fit)==nrow(d),all(fit$collin.var %in% "factor(res_char_type_resd)Split Level"))
  estimates <- as.data.table(coeftable(fit),keep.rownames="term")
  setnames(estimates,c("term","estimate","std_error","t_statistic","p_value"))
  intervals <- confint(fit)
  estimates[,`:=`(conf_low=intervals[,1],conf_high=intervals[,2])]
  estimates <- estimates[term=="treated_post" | grepl("^sale_year::[0-9]+:(treated|initial_price_100k)$",term)]
  estimates[,`:=`(model=model_name,initial_price_adjusted=as.integer(adjusted),
    component=ifelse(grepl("initial_price_100k$",term),"initial_price_year","treatment"),
    sale_year=as.integer(ifelse(term=="treated_post",NA_character_,sub("sale_year::([0-9]+):.*","\\1",term))))]
  stopifnot(estimates[component=="treatment",.N]==if(design=="did") 1L else 10L,
    estimates[component=="initial_price_year",.N]==if(adjusted) uniqueN(d$sale_year)-1L else 0L)
  if(!adjusted) {
    check <- merge(estimates,baseline[model==model_name,.(term,baseline_estimate=estimate,baseline_se=std_error)],by="term",all.x=TRUE)
    stopifnot(!anyNA(check$baseline_estimate),max(abs(check$estimate-check$baseline_estimate))<1e-6,
      max(abs(check$std_error-check$baseline_se))<1e-6)
  }
  pre <- if(design=="event") wald(fit,keep="^sale_year::(2008|2009|2010|2011):treated$",print=FALSE) else NULL
  models[[index]] <- data.table(model=model_name,initial_price_adjusted=as.integer(adjusted),
    observations=nobs(fit),treated_sites=uniqueN(d[treated==1,school_site_id]),control_sites=uniqueN(d[treated==0,school_site_id]),
    pretrend_p=if(design=="event") pf(pre$stat,pre$df1,uniqueN(d$school_site_id)-1,lower.tail=FALSE) else NA_real_)
  coefficients[[index]] <- estimates
}
coefficients <- rbindlist(coefficients)
models <- rbindlist(models)
stopifnot(nrow(coefficients)==164,nrow(models)==16,!anyDuplicated(coefficients[,.(model,initial_price_adjusted,term)]))
setorder(sites,school_site_id)
setorder(coefficients,model,initial_price_adjusted,term)
setorder(models,model,initial_price_adjusted)
fwrite(sites,"../output/initial_price_sites.csv")
fwrite(coefficients,"../output/initial_price_coefficients.csv")
fwrite(models,"../output/initial_price_models.csv")
print(coefficients[term=="treated_post",.(model,initial_price_adjusted,estimate,conf_low,conf_high)])
print(sites[,.(sites=.N,min_initial=min(initial_price),max_initial=max(initial_price),min_pre_sales=min(pre_sales),median_pre_sales=median(pre_sales)),by=treated])
