# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(duckdb)
  library(sf)
})
schools <- fread("../input/schools.csv")
reference <- fread("school_reference.csv")
raw_roster <- fread("../input/closure_roster.csv")
stopifnot(!anyDuplicated(schools$school_id), !anyDuplicated(reference$school_id),
  nrow(schools) == 129, sum(schools$housing_treat_30) == 30,
  sum(schools$housing_control_49) == 49,
  setequal(reference$school_id, schools[may2013_closed_47 == 1, school_id]))
# The published closure/receiving-school pairs are independently transcribed.
# Names identify programs; report-card coordinates identify their buildings.
for (i in seq_len(nrow(reference))) {
  school <- schools[school_id == reference$school_id[i]]
  stopifnot(grepl(reference$reference_name[i], school$school_name_sy1213, ignore.case = TRUE))
  expected <- strsplit(reference$welcoming_name_tokens[i], ";", fixed = TRUE)[[1]]
  observed <- unlist(school[, paste0("welcoming_school_name", 1:3, "_sy1314"), with = FALSE])
  observed <- observed[!is.na(observed)]
  stopifnot(length(expected) == length(observed),
    all(vapply(expected, function(token) any(grepl(token, observed, fixed = TRUE)), logical(1))))
}
# All original sample flags and welcoming IDs must survive cleaning unchanged.
candidates <- fread("candidate_reference.csv")
stopifnot(nrow(candidates)==129, !anyDuplicated(candidates$school_id),
  setequal(candidates$school_id, schools$school_id),
  identical(candidates$source_roster_name,raw_roster$SCHOOL_NM[match(candidates$school_id,raw_roster$SCHOOL_ID)]))
setnames(raw_roster, tolower(names(raw_roster)))
stopifnot(!anyDuplicated(raw_roster$school_id), setequal(raw_roster$school_id, schools$school_id))
for (field in c("feb2013_candidate_129", "mar2013_candidate_54", "may2013_closed_47",
                "may2013_welcoming_18", "consortium_treat_47", "consortium_control_49",
                "housing_treat_30", "housing_control_49", paste0("welcoming_school_id", 1:3))) {
  stopifnot(identical(schools[[field]], raw_roster[[field]][match(schools$school_id, raw_roster$school_id)]))
}
schools[, group := fcase(housing_treat_30 == 1, "Closed", housing_control_49 == 1, "Stayed open", default = "Other candidate")]
stopifnot(all(schools[housing_treat_30 == 1, may2013_closed_47] == 1),
  all(schools[housing_control_49 == 1, may2013_closed_47] == 0),
  all(schools[housing_control_49 == 1, report_card_match_sy1314]))
# Verify the swapped latitude/longitude labels and the projected school units.
points <- st_as_sf(schools, coords = c("longitude_sy1213", "latitude_sy1213"), crs = 4326)
stopifnot(all(st_is_valid(points)))
projected <- st_coordinates(st_transform(points, 3435))
schools[, projection_error_ft := sqrt((projected[,1] - x_coordinate_sy1213)^2 +
                                      (projected[,2] - y_coordinate_sy1213)^2)]
stopifnot(max(schools$projection_error_ft) < 2)
welcoming <- rbindlist(lapply(1:3, function(i) schools[!is.na(get(paste0("welcoming_school_id", i))), .(
  closed_school_id = school_id, school_id = get(paste0("welcoming_school_id", i)),
  school_name = get(paste0("welcoming_school_name", i, "_sy1314")),
  address = get(paste0("welcoming_school_street_address", i, "_sy1314")),
  x = get(paste0("welcoming_school_x_coordinate", i, "_sy1314")),
  y = get(paste0("welcoming_school_y_coordinate", i, "_sy1314")),
  lon = get(paste0("welcoming_school_longitude", i, "_sy1314")),
  lat = get(paste0("welcoming_school_latitude", i, "_sy1314")))]))
stopifnot(nrow(welcoming) == 53, uniqueN(welcoming$school_id) == 48, !anyNA(welcoming),
  !anyDuplicated(welcoming[, .(closed_school_id, school_id)]))
welcoming_points <- st_coordinates(st_transform(st_as_sf(welcoming, coords=c("lon","lat"), crs=4326),3435))
stopifnot(max(sqrt((welcoming_points[,1]-welcoming$x)^2+(welcoming_points[,2]-welcoming$y)^2)) < 2)
# Published relocation decisions should agree with the pre/post location data.
welcoming[, distance_to_closed_ft := sqrt((x-schools$x_coordinate_sy1213[match(closed_school_id,schools$school_id)])^2+
  (y-schools$y_coordinate_sy1213[match(closed_school_id,schools$school_id)])^2)]
relocated <- reference[welcoming_moved_into_closed_building == 1, school_id]
stopifnot(length(relocated) == 15, all(welcoming[closed_school_id %in% relocated, distance_to_closed_ft] < 300))
continued <- c(relocated, 609916L, 400095L)
stopifnot(setequal(continued, schools[may2013_closed_47==1 & housing_treat_30==0, school_id]))
# Fermi/South Shore and Garfield/Faraday are the two supplied co-location cases.
# The Garfield coordinate substitution is not independent address evidence.
stopifnot(all(welcoming[closed_school_id %in% c(609916L,400095L), distance_to_closed_ft] < 300))
sites <- schools[, .(school_names = paste(trimws(school_name_sy1213), collapse=" / "),
  group=group[1], x=x_coordinate_sy1213[1], y=y_coordinate_sy1213[1],
  schools=.N), by=school_site_id]
stopifnot(nrow(sites)==127, all(schools[,uniqueN(group),by=school_site_id]$V1==1))
site_distances <- as.matrix(dist(sites[,.(x,y)]))
near_pairs <- which(upper.tri(site_distances) & site_distances < 300, arr.ind=TRUE)
near_sites <- data.table(site1=sites$school_site_id[near_pairs[,1]],site2=sites$school_site_id[near_pairs[,2]],
  distance_ft=site_distances[near_pairs])

sales <- fread("../input/corrected_sales.csv", colClasses=c(row_id="character",pin="character",sale_document_num="character"))
clean <- fread("../input/clean_sales.csv", colClasses=c(row_id="character",pin="character",sale_document_num="character"))
geo <- fread("../input/geocoded_master.csv", select=c("row_id","pin","sale_year","longitude","latitude",
  "centroid_x_crs_3435","centroid_y_crs_3435","has_historical_coordinates"),colClasses=c(row_id="character",pin="character"))
con <- dbConnect(duckdb(), dbdir=":memory:")
exposure <- as.data.table(dbGetQuery(con,"SELECT * FROM read_parquet('../input/exposure.parquet')"))
dbDisconnect(con,shutdown=TRUE)
exposure[,row_id:=as.character(row_id)]
stopifnot(nrow(sales)==428582, !anyDuplicated(sales$row_id), !anyDuplicated(clean$row_id),
  !anyDuplicated(geo$row_id),!anyDuplicated(exposure$row_id),setequal(sales$row_id,geo$row_id),
  setequal(sales$row_id,exposure$row_id))
# Many sales to one historical parcel-year location; compare coordinates in both CRSs.
geo_keys <- unique(geo[,.(pin,sale_year,longitude,latitude,centroid_x_crs_3435,centroid_y_crs_3435,has_historical_coordinates)])
stopifnot(!anyDuplicated(geo_keys[,.(pin,sale_year)]))
xy <- st_coordinates(st_transform(st_as_sf(geo_keys[has_historical_coordinates==TRUE],coords=c("longitude","latitude"),crs=4326),3435))
parcel_projection_error <- max(sqrt((xy[,1]-geo_keys[has_historical_coordinates==TRUE,centroid_x_crs_3435])^2+
 (xy[,2]-geo_keys[has_historical_coordinates==TRUE,centroid_y_crs_3435])^2))
stopifnot(parcel_projection_error < 1)
sales <- merge(sales,geo[,.(row_id,x=centroid_x_crs_3435,y=centroid_y_crs_3435)],by="row_id",all.x=TRUE)
sales <- merge(sales,exposure,by="row_id",all.x=TRUE)
stopifnot(nrow(sales)==428582,!anyDuplicated(sales$row_id))
sales <- sales[sale_year %between% c(2008L,2018L)]
# Recompute proximity from coordinates, independently of the distance parquet.
# Every study-period transaction is checked against every relevant location.
for (category in c("Closed","Stayed open","Other candidate","Welcoming")) {
  locations <- if(category=="Welcoming") unique(welcoming[,.(school_site_id=school_id,x,y)]) else sites[group==category,.(school_site_id,x,y)]
  setorder(locations,school_site_id)
  count <- rep(0L, nrow(sales))
  nearest <- rep(Inf, nrow(sales))
  nearest_id <- rep(NA_integer_, nrow(sales))
  for(i in seq_len(nrow(locations))) {
    distance <- sqrt((sales$x-locations$x[i])^2+(sales$y-locations$y[i])^2)
    count <- count+as.integer(is.finite(distance) & distance<=1320)
    closer <- which(is.finite(distance) & distance<nearest)
    nearest[closer] <- distance[closer]
    nearest_id[closer] <- locations$school_site_id[i]
  }
  prefix <- switch(category,Closed="treated_site","Stayed open"="control_site","Other candidate"="other_candidate_site",Welcoming="welcoming_school")
  count_field <- switch(category,Closed="n_treated_sites_025","Stayed open"="n_control_sites_025","Other candidate"="n_other_candidate_sites_025",Welcoming="n_welcoming_schools_025")
  valid <- is.finite(sales$x) & is.finite(sales$y)
  stopifnot(all(count[valid]==sales[[count_field]][valid]),
    max(abs(nearest[valid]-sales[[paste0("nearest_",prefix,"_distance_feet")]][valid]))<1e-6,
    all(nearest_id[valid]==sales[[paste0("nearest_",prefix,"_id")]][valid]))
}
sales[,group:=fcase(focal_exposure_025=="treated_only","Closed",focal_exposure_025=="control_only","Stayed open",default="Outside comparison")]
sales[,geography_ok:=group!="Outside comparison" & n_welcoming_schools_025==0 & n_other_candidate_sites_025==0]
sales[,school_site_id:=fifelse(group=="Closed",nearest_treated_site_id,nearest_control_site_id)]
# Independent sequential reconstruction of the price cleaner. Conditions are
# evaluated on the citywide data before the citywide, within-year tail cutoff.
conditions <- list(
  "Recorded non-condo transactions"=rep(TRUE,nrow(sales)),
  "County sale-quality flags"=!sales$sale_filter_same_sale_within_365 & !sales$sale_filter_less_than_10k & !sales$sale_filter_deed_type,
  "Non-land sales above $10,000"=is.finite(sales$sale_price_nominal) & sales$sale_price_nominal>10000 & !is.na(sales$sale_type) & sales$sale_type!="LAND",
  "One building record; eligible property type"=sales$single_improvement_card & sales$analysis_class %in% c(202:211,234,278,295),
  "Complete property characteristics"=is.finite(sales$res_char_yrblt) & is.finite(sales$res_char_bldg_sf) & sales$res_char_bldg_sf>0 &
    is.finite(sales$res_char_land_sf) & sales$res_char_land_sf>0 & is.finite(sales$res_char_beds) & is.finite(sales$res_char_rooms) & is.finite(sales$res_char_fbath) &
    !is.na(sales$res_char_type_resd) & nzchar(trimws(sales$res_char_type_resd)) & !is.na(sales$res_char_cnst_qlty) & nzchar(trimws(sales$res_char_cnst_qlty)) &
    !is.na(sales$res_char_repair_cnd) & nzchar(trimws(sales$res_char_repair_cnd)) & (sales$analysis_class!=211 | sales$res_char_apts %in% c("Two","Three","Four","Five","Six")),
  "Consistent rooms; price per sq. ft. <= $5,000"=sales$res_char_rooms>=sales$res_char_beds & sales$sale_price_nominal/sales$res_char_bldg_sf<=5000)
included <- rep(TRUE, nrow(sales))
attrition <- list()
annual_counts <- list()
for(i in seq_along(conditions)) {
  included <- included & !is.na(conditions[[i]]) & conditions[[i]]
  attrition[[i]] <- rbindlist(list(data.table(group="Citywide",sales=sum(included)),sales[included & geography_ok,.(sales=.N),by=group]))[,`:=`(step=i,restriction=names(conditions)[i])]
  annual_counts[[i]] <- sales[included & geography_ok,.(sales=.N,parcels=uniqueN(pin)),by=.(group,sale_year)][,stage:=i]
  if(i==3) sales[,market_sale:=included]
}
candidates <- sales[included,.(row_id,sale_year,ppsf=sale_price_nominal/res_char_bldg_sf)]
candidates[,cutoff:=quantile(ppsf,.999,type=7),by=sale_year]
cutoffs <- candidates[,.(cutoff=cutoff[1],removed=sum(ppsf>cutoff)),by=sale_year]
included <- sales$row_id %in% candidates[ppsf<=cutoff,row_id]
stopifnot(setequal(sales$row_id[included],clean$row_id),sum(included)==167468)
sales[,price_sample:=included]
attrition[[7]] <- rbindlist(list(data.table(group="Citywide",sales=sum(included)),sales[included & geography_ok,.(sales=.N),by=group]))[,`:=`(step=7L,restriction="Trim annual top 0.1% of price per sq. ft.")]
annual_counts[[7]] <- sales[included & geography_ok,.(sales=.N,parcels=uniqueN(pin)),by=.(group,sale_year)][,stage:=7L]
attrition <- rbindlist(attrition)
annual_counts <- rbindlist(annual_counts)
# Descriptive trends retain sales with incomplete characteristics. Keep the
# existing annual price-per-square-foot cutoffs to isolate this sample change.
# Missing fields cannot fail checks that require those fields to be observed.
regression_attrition <- copy(attrition)
regression_counts <- copy(annual_counts)
sales[, usable_area := is.finite(res_char_bldg_sf) & res_char_bldg_sf > 0]
sales[, ppsf := fifelse(usable_area, sale_price_nominal/res_char_bldg_sf, NA_real_)]
sales[cutoffs, on="sale_year", ppsf_cutoff := i.cutoff]
sales[, observed_rooms_error := is.finite(res_char_rooms) & is.finite(res_char_beds) & res_char_rooms < res_char_beds]
broad <- rep(TRUE,nrow(sales))
for(i in 1:4) broad <- broad & !is.na(conditions[[i]]) & conditions[[i]]
attrition <- regression_attrition[step<=4]
annual_counts <- regression_counts[stage<=4]
attrition <- rbind(attrition,copy(attrition[step==4])[,`:=`(step=5L,restriction="Keep incomplete property characteristics")])
annual_counts <- rbind(annual_counts,copy(annual_counts[stage==4])[,stage:=5L])
broad <- broad & !sales$observed_rooms_error & (is.na(sales$ppsf) | sales$ppsf<=5000)
attrition <- rbind(attrition,rbindlist(list(data.table(group="Citywide",sales=sum(broad)),sales[broad & geography_ok,.(sales=.N),by=group]))[,`:=`(step=6L,restriction="Apply plausibility screens where observed")])
annual_counts <- rbind(annual_counts,sales[broad & geography_ok,.(sales=.N,parcels=uniqueN(pin)),by=.(group,sale_year)][,stage:=6L])
sales[,trend_sample:=broad & (is.na(ppsf) | ppsf<=ppsf_cutoff)]
stopifnot(all(sales[price_sample==TRUE,trend_sample]))
attrition <- rbind(attrition,rbindlist(list(data.table(group="Citywide",sales=sum(sales$trend_sample)),sales[trend_sample & geography_ok,.(sales=.N),by=group]))[,`:=`(step=7L,restriction="Apply existing annual price-per-sq.-ft. cutoffs")])
annual_counts <- rbind(annual_counts,sales[trend_sample & geography_ok,.(sales=.N,parcels=uniqueN(pin)),by=.(group,sale_year)][,stage:=7L])

# Inflation adjustment is also reconstructed, using one monthly CPI observation.
cpi <- fread("../input/cpi.csv")
cpi[,`:=`(sale_year=as.integer(substr(observation_date,1,4)),sale_month=as.integer(substr(observation_date,6,7)))]
stopifnot(!anyDuplicated(cpi[,.(sale_year,sale_month)]),cpi[sale_year==2022,.N]==12)
base_cpi <- cpi[sale_year==2022,mean(chicago_cpi_all_items)]
sales[cpi,on=.(sale_year,sale_month),deflator:=base_cpi/i.chicago_cpi_all_items]
sales[,real_price:=sale_price_nominal*deflator]
stopifnot(max(abs(sales[row_id %in% clean$row_id,real_price]-clean$sale_price_real_2022[match(sales[row_id %in% clean$row_id,row_id],clean$row_id)]))<1e-7)
# Annual means, medians, and percentiles give each transaction equal weight.
complete <- sales[price_sample & geography_ok]
stopifnot(nrow(complete)==10921,complete[group=="Closed",.N]==3287,complete[group=="Stayed open",.N]==7634)
complete_prices <- complete[,.(sales=.N,mean_price=mean(real_price),median_price=median(real_price)),by=.(group,sale_year)]
selected <- sales[trend_sample & geography_ok]
stopifnot(!anyNA(selected$real_price), !anyDuplicated(selected$row_id), all(complete$row_id %in% selected$row_id))
sample_changes <- selected[,.(sales=.N,complete_sales=sum(price_sample),added=sum(!price_sample),
  added_blank_apartment_count=sum(!price_sample & analysis_class==211 & (is.na(res_char_apts) | !nzchar(trimws(res_char_apts)))),
  usable_area_sales=sum(usable_area)),by=.(group,sale_year)]
annual_prices <- selected[,.(sales=.N,mean_price=mean(real_price),median_price=median(real_price),
  nominal_mean=mean(sale_price_nominal),nominal_median=as.numeric(median(sale_price_nominal)),
  p10=quantile(real_price,.10),p25=quantile(real_price,.25),p75=quantile(real_price,.75),p90=quantile(real_price,.90),p95=quantile(real_price,.95),
  top5_value_share=sum(real_price[real_price>quantile(real_price,.95)])/sum(real_price),
  mean_ppsf=mean(real_price[usable_area]/res_char_bldg_sf[usable_area]),median_ppsf=median(real_price[usable_area]/res_char_bldg_sf[usable_area])),by=.(group,sale_year)]
selected[,property_type:=fifelse(analysis_class==211,"Apartment buildings (2-6 units)","Houses and townhouses")]
composition <- selected[,.(sales=.N,mean_price=mean(real_price),median_price=median(real_price),
  usable_area_sales=sum(usable_area),mean_sqft=mean(res_char_bldg_sf[usable_area]),median_sqft=as.numeric(median(res_char_bldg_sf[usable_area])),mean_age=mean(sale_year-res_char_yrblt,na.rm=TRUE),
  hie_share=mean(hie_correction_eligible),hie_start_year_share=mean(hie_start_year_timing_uncertain)),by=.(group,sale_year,property_type)]
composition[,share:=sales/sum(sales),by=.(group,sale_year)]
support <- merge(sites[group!="Other candidate"],selected[,.(sales=.N,parcels=uniqueN(pin),pre_sales=sum(sale_year<=2012),post_sales=sum(sale_year>=2014)),by=school_site_id],by="school_site_id",all.x=TRUE)
for(field in c("sales","parcels","pre_sales","post_sales")) set(support,which(is.na(support[[field]])),field,0L)
site_year <- merge(CJ(school_site_id=support$school_site_id,sale_year=2008:2018),selected[,.(sales=.N),by=.(school_site_id,sale_year)],by=c("school_site_id","sale_year"),all.x=TRUE)
site_year[is.na(sales),sales:=0L]
geography <- sales[trend_sample == TRUE,.(sales=.N),by=.(focal_exposure_025,n_welcoming_schools_025,n_other_candidate_sites_025)]
selection <- annual_counts[stage %in% c(3,7)]
selection <- dcast(selection,group+sale_year~stage,value.var="sales")
setnames(selection,c("3","7"),c("market_sales","price_sales"))
selection[,retention:=price_sales/market_sales]
# Sensitivity is descriptive: retain price rules but relax competing-school exclusions.
location_variants <- rbindlist(list(
 sales[trend_sample & group!="Outside comparison",.(group,sale_year,real_price,variant="Before nearby-school exclusions")],
 selected[,.(group,sale_year,real_price,variant="Preferred geography")]))[,.(sales=.N,mean_price=mean(real_price),median_price=median(real_price)),by=.(group,sale_year,variant)]
checks <- data.table(check=c("February candidate names checked","Master transactions","Study-period transactions","Complete-characteristics citywide prices","Descriptive comparison prices","School projection maximum (feet)","Parcel projection maximum (feet)","Missing master coordinates","Published closure pairs checked","Receiving-school assignments checked","Distinct receiving schools","Nearby distinct candidate site pairs (<300 feet)"),
 value=c(129,428582,nrow(sales),nrow(clean),nrow(selected),max(schools$projection_error_ft),parcel_projection_error,sum(!geo$has_historical_coordinates),47,53,48,nrow(near_sites)))
setorder(schools, school_id)
setorder(annual_prices, group, sale_year)
setorder(composition, group, property_type, sale_year)
setorder(support, group, -sales)
setorder(annual_counts, stage, group, sale_year)
setorder(attrition, group, step)
saveRDS(list(checks=checks,schools=schools[,.(school_id,school_site_id,school_name_sy1213,group,may2013_closed_47,housing_treat_30,housing_control_49,street_address_sy1213,notes,projection_error_ft)],
 welcoming=welcoming,sites=sites,near_sites=near_sites,attrition=attrition,annual_counts=annual_counts,annual_prices=annual_prices,
 complete_prices=complete_prices,sample_changes=sample_changes,regression_attrition=regression_attrition,
 composition=composition,support=support,site_year=site_year,geography=geography,selection=selection,cutoffs=cutoffs,location_variants=location_variants,
 map_sales=selected[,.(row_id,x,y,group)],date_precision=selected[,.(sales=.N),by=.(group,sale_date_precision)],
 source_hashes=data.table(source=c("school roster","corrected transactions","clean prices","historical locations","exposure","CPI","published school report","reference transcription","February list","February transcription","CPS Fermi notice","CPS Garfield notice"),
 sha256=vapply(c("../input/closure_roster.csv","../input/corrected_sales.csv","../input/clean_sales.csv","../input/geocoded_master.csv","../input/exposure.parquet","../input/cpi.csv","../input/consortium_school_closings_2015.pdf","school_reference.csv","../input/cps_february_2013_list.pdf","candidate_reference.csv","../input/fermi_south_shore_2013.pdf","../input/garfield_faraday_2013.pdf"),digest::digest,character(1),file=TRUE,algo="sha256"))),"../output/data_review.rds")
print(checks)
print(attrition)
print(welcoming[closed_school_id %in% continued, .(closed_school_id, school_name, distance_to_closed_ft)])
