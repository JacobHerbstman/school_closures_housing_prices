# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/tract_demographic_change/code")
suppressPackageStartupMessages({library(data.table); library(sf)})
source("../../../shared/code/report_data.R")

counts <- fread("../output/census_tract_counts.csv", colClasses = list(character = "geoid"))
# The ACS codes suppressed estimates as large negative numbers (five tracts'
# aggregate household income); they are missing, not values.
counts[value < 0, value := NA_real_]
wide <- dcast(counts, vintage + geoid ~ measure, value.var = "value")
wide[, ba_plus := male_ba + male_ma + male_prof + male_phd + female_ba + female_ma + female_prof + female_phd]
count_columns <- c("adults_25", "ba_plus", "population", "nh_white", "nh_black", "aggregate_household_income", "households")

# 2000 tracts onto 2010 tracts: each 2010 tract receives each overlapping 2000
# tract's counts in proportion to the share of that 2000 tract's population in
# the overlap (Census 2010 tract relationship file, field POPPCT00).
relationship <- fread("../output/il17trf.txt", header = FALSE, colClasses = "character")
relationship <- relationship[, .(geoid00 = V4, geoid10 = V13, population00 = as.numeric(V5),
                                 share_of_2000 = as.numeric(V26) / 100)][
  startsWith(geoid00, "17031") & startsWith(geoid10, "17031")]
# Shares of each populated 2000 tract sum to one; zero-population tracts have none.
stopifnot(!anyDuplicated(relationship[, .(geoid00, geoid10)]),
          all(abs(relationship[population00 > 0, sum(share_of_2000), by = geoid00]$V1 - 1) < 0.02))
tracts_2000 <- wide[vintage == "2000", c("geoid", count_columns), with = FALSE]
stopifnot(all(relationship[population00 > 0, geoid00] %in% tracts_2000$geoid))
allocated <- merge(relationship, tracts_2000, by.x = "geoid00", by.y = "geoid")
allocated <- allocated[, lapply(.SD, function(x) sum(x * share_of_2000)), by = geoid10, .SDcols = count_columns]
tracts_2012 <- wide[vintage == "2008-2012", c("geoid", count_columns), with = FALSE]
setnames(tracts_2012, "geoid", "geoid10")
tracts <- merge(allocated, tracts_2012, by = "geoid10", suffixes = c("_2000", "_2012"))
stopifnot(!anyDuplicated(tracts$geoid10), nrow(tracts) > 1000L)

# Shares in percentage points; mean household income in 2012 dollars. The
# 2000 Census reports 1999 income: CPI-U annual averages 166.6 (1999) and
# 229.594 (2012). Tracts with fewer than 100 adults or households in either
# vintage give unreliable shares and are left missing.
cpi_1999_to_2012 <- 229.594 / 166.6
tracts[, `:=`(
  ba_share_2000 = 100 * ba_plus_2000 / adults_25_2000, ba_share_2012 = 100 * ba_plus_2012 / adults_25_2012,
  nh_white_share_2000 = 100 * nh_white_2000 / population_2000, nh_white_share_2012 = 100 * nh_white_2012 / population_2012,
  nh_black_share_2000 = 100 * nh_black_2000 / population_2000, nh_black_share_2012 = 100 * nh_black_2012 / population_2012,
  mean_income_2000 = cpi_1999_to_2012 * aggregate_household_income_2000 / households_2000,
  mean_income_2012 = aggregate_household_income_2012 / households_2012
)]
reliable <- tracts[, pmin(adults_25_2000, adults_25_2012, households_2000, households_2012) >= 100]
tracts[, `:=`(
  change_ba_share = fifelse(reliable, ba_share_2012 - ba_share_2000, NA_real_),
  change_nh_white_share = fifelse(reliable, nh_white_share_2012 - nh_white_share_2000, NA_real_),
  change_nh_black_share = fifelse(reliable, nh_black_share_2012 - nh_black_share_2000, NA_real_),
  change_log_mean_income = fifelse(reliable, log(mean_income_2012) - log(mean_income_2000), NA_real_)
)]

# Each master sale to its 2010 tract by point in polygon, in EPSG:3435 feet.
geocoded <- fread("../input/geocoded_master_home_transactions_2006_2025.csv",
                  select = c("row_id", "has_historical_coordinates", "centroid_x_crs_3435", "centroid_y_crs_3435"),
                  colClasses = list(character = "row_id"))
stopifnot(!anyDuplicated(geocoded$row_id))
geocoded <- geocoded[has_historical_coordinates == TRUE]
unzip("../output/tl_2010_17031_tract10.zip", exdir = "../temp/tracts")
tract_shapes <- st_transform(st_read(list.files("../temp/tracts", pattern = "\\.shp$", full.names = TRUE),
                                     quiet = TRUE)[, "GEOID10"], 3435)
stopifnot(all(st_is_valid(tract_shapes)), !anyDuplicated(tract_shapes$GEOID10))
points <- st_as_sf(geocoded, coords = c("centroid_x_crs_3435", "centroid_y_crs_3435"), crs = 3435)
hits <- st_intersects(points, tract_shapes)
stopifnot(all(lengths(hits) <= 1L), mean(lengths(hits) == 1L) > 0.999)
geocoded[, geoid10 := NA_character_]
geocoded[lengths(hits) == 1L, geoid10 := tract_shapes$GEOID10[unlist(hits)]]
unlink("../temp/tracts", recursive = TRUE)

change_columns <- c("change_ba_share", "change_nh_white_share", "change_nh_black_share", "change_log_mean_income")
level_columns <- c("ba_share_2000", "nh_white_share_2000", "nh_black_share_2000", "mean_income_2000")
sales <- merge(geocoded[, .(row_id, geoid10)], tracts[, c("geoid10", change_columns, level_columns), with = FALSE],
               by = "geoid10", all.x = TRUE)
stopifnot(!anyDuplicated(sales$row_id), mean(!is.na(sales$change_ba_share)) > 0.99)
setorder(sales, row_id)
fwrite(sales, "../output/sale_tract_change.csv", na = "NA")
report <- capture.output({
  cat("CSV SHA-256:", digest::digest("../output/sale_tract_change.csv", file = TRUE, algo = "sha256"), "\n")
  report_data(sales, "sale_tract_change", "row_id")
  report_data(tracts, "tracts", "geoid10")
})
writeLines(trimws(report, which = "right"), "../report/sale_tract_change.txt")
print(tracts[, lapply(.SD, function(x) round(quantile(x, c(0.1, 0.5, 0.9), na.rm = TRUE), 3)), .SDcols = change_columns])
cat(sprintf("Sales assigned to a tract: %s of %s\n", format(sum(!is.na(sales$geoid10)), big.mark = ","),
            format(nrow(sales), big.mark = ",")))
