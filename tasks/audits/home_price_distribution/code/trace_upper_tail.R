# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
library(data.table)
sales <- fread("../output/analysis_sample.csv", colClasses=c(row_id="character",pin="character"))
stopifnot(!anyDuplicated(sales$row_id))
# Annual, group-specific ranks describe different parts of the price distribution.
sales[, price_band := {
  cutoffs <- quantile(sale_price_real_2022,c(.50,.75,.95),type=7)
  fcase(sale_price_real_2022 <= cutoffs[1], "0-50", sale_price_real_2022 <= cutoffs[2], "50-75",
    sale_price_real_2022 <= cutoffs[3], "75-95", default="95-100")
}, by=.(treated,sale_year)]
sales <- sales[sale_year != 2013]
sales[, period := fifelse(sale_year <= 2012,"2008-2012","2014-2018")]
bands <- sales[, .(sales=.N, sale_value=sum(sale_price_real_2022),mean_price=mean(sale_price_real_2022),
  apartment_share=mean(analysis_class==211), mean_building_sqft=mean(res_char_bldg_sf),
  mean_age=mean(age_at_sale)),by=.(treated,period,price_band)]
bands[, `:=`(sale_share=sales/sum(sales),contribution_to_mean=sale_value/sum(sales)),by=.(treated,period)]
# All sales stay in the denominator, including sites with no upper-quarter sales.
sites <- sales[, {
  upper <- price_band %in% c("75-95","95-100")
  .(school_names=school_names[1],sales=.N,mean_price=mean(sale_price_real_2022),upper_sales=sum(upper),
    upper_sale_value=sum(sale_price_real_2022[upper]),
    upper_mean_price=if(any(upper)) mean(sale_price_real_2022[upper]) else NA_real_,
    upper_apartment_share=if(any(upper)) mean(analysis_class[upper]==211) else NA_real_,
    upper_mean_building_sqft=if(any(upper)) mean(res_char_bldg_sf[upper]) else NA_real_,
    upper_mean_age=if(any(upper)) mean(age_at_sale[upper]) else NA_real_)
},by=.(treated,period,school_site_id)]
sites[, `:=`(upper_contribution_to_group_mean=upper_sale_value/sum(sales),
  share_of_group_upper_value=upper_sale_value/sum(upper_sale_value),
  share_of_group_upper_sales=upper_sales/sum(upper_sales)),by=.(treated,period)]
# Each group-period has one raw mean, reconstructed from disjoint price bands.
means <- sales[,.(raw_mean=mean(sale_price_real_2022)),by=.(treated,period)]
check <- merge(means,bands[,.(reconstructed=sum(contribution_to_mean)),by=.(treated,period)],by=c("treated","period"))
stopifnot(nrow(check)==4, max(abs(check$raw_mean-check$reconstructed))<1e-7)
check <- merge(sites[,.(site_contribution=sum(upper_contribution_to_group_mean)),by=.(treated,period)],
  bands[price_band %in% c("75-95","95-100"),.(band_contribution=sum(contribution_to_mean)),by=.(treated,period)],by=c("treated","period"))
stopifnot(nrow(check)==4,max(abs(check$site_contribution-check$band_contribution))<1e-7,
  nrow(bands)==16,!anyDuplicated(bands[,.(treated,period,price_band)]),
  !anyDuplicated(sites[,.(treated,period,school_site_id)]),sum(sites$sales)==9912,
  !anyNA(sites[upper_sales>0]),all(is.na(sites[upper_sales==0,upper_mean_price])))
setorder(bands,treated,period,price_band)
setorder(sites,treated,period,school_site_id)
fwrite(bands,"../output/price_band_periods.csv")
fwrite(sites,"../output/upper_tail_sites.csv")
print(bands)
print(sites[treated==1 & period=="2014-2018"][order(-upper_sale_value)][1:6])
