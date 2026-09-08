# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
suppressPackageStartupMessages({library(data.table); library(DBI); library(duckdb)})
sales <- fread("../input/home_sales_2008_2018.csv", colClasses = c(row_id = "character", pin = "character"),
  select = c("row_id", "pin", "sale_year", "sale_month", "sale_price_real_2022", "sale_price_nominal",
    "res_char_bldg_sf", "res_char_land_sf", "res_char_yrblt", "res_char_beds", "res_char_rooms",
    "res_char_fbath", "apartment_count", "analysis_class", "res_char_type_resd", "res_char_cnst_qlty", "res_char_repair_cnd"))
connection <- dbConnect(duckdb(), dbdir = ":memory:")
exposure <- as.data.table(dbGetQuery(connection, "
 SELECT CAST(row_id AS VARCHAR) AS row_id, focal_exposure_025,
 nearest_treated_site_id, nearest_control_site_id, n_welcoming_schools_025,
 n_other_candidate_sites_025
 FROM read_parquet('../input/home_school_exposure_2006_2025.parquet')"))
dbDisconnect(connection, shutdown = TRUE)
# Every clean sale matches one exposure record. Same-status overlaps enter once.
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(exposure$row_id), all(sales$row_id %in% exposure$row_id))
sales <- merge(sales, exposure, by = "row_id", all.x = TRUE)
sales <- sales[focal_exposure_025 %in% c("treated_only", "control_only") &
  n_welcoming_schools_025 == 0 & n_other_candidate_sites_025 == 0]
sales[, `:=`(treated = as.integer(focal_exposure_025 == "treated_only"),
  school_site_id = fifelse(focal_exposure_025 == "treated_only", nearest_treated_site_id, nearest_control_site_id))]
# School records can share a physical site. Combine names only after status agrees.
schools <- fread("../input/schools.csv")
schools <- schools[housing_treat_30 == 1 | housing_control_49 == 1]
stopifnot(!anyDuplicated(schools$school_id), sum(schools$housing_treat_30) == 30,
  sum(schools$housing_control_49) == 49,
  all(schools[, uniqueN(housing_treat_30), by = school_site_id]$V1 == 1))
setorder(schools, school_site_id, school_id)
sites <- schools[, .(school_names = paste(trimws(school_name_sy1213), collapse = " / "),
  treated = housing_treat_30[1]), by = school_site_id]
stopifnot(!anyDuplicated(sites$school_site_id), all(sales$school_site_id %in% sites$school_site_id))
rows_before <- nrow(sales)
sales <- merge(sales, sites, by = c("school_site_id", "treated"), all.x = TRUE)
stopifnot(nrow(sales) == rows_before, !anyNA(sales$school_names))
sales[, `:=`(property_type = fifelse(analysis_class == 211, "Apartments (2-6 units)", "Houses/townhouses"),
  log_real_price = log(sale_price_real_2022), log_building_sqft = log(res_char_bldg_sf),
  log_land_sqft = log(res_char_land_sf), age_at_sale = sale_year - res_char_yrblt,
  apartments = fcoalesce(apartment_count, 0L))]
stopifnot(all(sales$analysis_class %in% c(202:211,234,278,295)),
  all(sales$sale_price_real_2022 > 0), !anyNA(sales[analysis_class == 211, apartment_count]),
  all(complete.cases(sales[, .(log_real_price, log_building_sqft, log_land_sqft, age_at_sale,
    res_char_beds, res_char_rooms, res_char_fbath, apartments, res_char_type_resd, res_char_cnst_qlty, res_char_repair_cnd)])))
# Match the baseline sample's complete site-year counts and observed mean prices.
support <- sales[, .(sales = .N, mean_real_price = mean(sale_price_real_2022)), by = .(school_site_id, treated, sale_year)]
baseline <- fread("../input/baseline_site_year_support.csv")
stopifnot(!anyDuplicated(baseline[, .(school_site_id, treated, sale_year)]))
check <- merge(support, baseline, by = c("school_site_id", "treated", "sale_year"), all = TRUE)
stopifnot(!anyNA(check), all(check$sales.x == check$sales.y),
  max(abs(check$mean_real_price.x - check$mean_real_price.y)) < 1e-6,
  nrow(sales) == 10921, uniqueN(sales[treated == 1, school_site_id]) == 29,
  uniqueN(sales[treated == 0, school_site_id]) == 48, !anyDuplicated(sales$row_id))
sales[, c("focal_exposure_025", "nearest_treated_site_id", "nearest_control_site_id",
  "n_welcoming_schools_025", "n_other_candidate_sites_025") := NULL]
setorder(sales, row_id)
fwrite(sales, "../output/analysis_sample.csv")
print(sales[, .(sales = .N, sites = uniqueN(school_site_id)), by = treated])
