# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_baseline_demographics/code")
suppressPackageStartupMessages({library(data.table); library(sf); library(DBI); library(duckdb); library(digest)})

# Census geographic header: documented CSV fields 3, 5, 49, 50. LOGRECNO
# identifies one geographic record within this state's summary file.
header <- fread("../input/g20125il.csv", header = FALSE, colClasses = "character",
                select = c(3, 5, 49, 50), col.names = c("summary_level", "logrecno", "acs_geoid", "name"))
header[, geoid := sub("^.*US", "", acs_geoid)]
header <- header[summary_level %in% c("140", "150") & substr(geoid, 1, 5) == "17031"]
header[, geography := fifelse(summary_level == "140", "tract", "block_group")]
stopifnot(!anyDuplicated(header$logrecno), !anyDuplicated(header$geoid),
          all(nchar(header$geoid) == fifelse(header$geography == "tract", 11L, 12L)))
lookup <- fread("../input/sequence_lookup.txt", encoding = "Latin-1", colClasses = "character")

# This list varies by substantive table; source lookup supplies sequence and
# column offsets, rather than inferring them from the downloaded data values.
table_lines <- list(B03002 = c(1, 3, 4, 12), B15003 = c(1, 22:25),
                    C17002 = c(1, 2, 3), B19013 = 1, B23025 = c(3, 5),
                    B25002 = c(1, 3), B25003 = c(1, 3))
demographics <- copy(header[, .(geography, geoid, name, logrecno)])
for (table_id in names(table_lines)) {
  definition <- lookup[get("Table ID") == table_id & trimws(get("Start Position")) != ""]
  stopifnot(nrow(definition) == 1L)
  sequence_id <- definition[["Sequence Number"]]
  columns <- as.integer(definition[["Start Position"]]) + table_lines[[table_id]] - 1L
  for (kind in c("e", "m")) {
    source <- read.csv(unz(sprintf("../input/20125il%s000.zip", sequence_id),
      sprintf("%s20125il%s000.txt", kind, sequence_id)), header = FALSE,
      colClasses = "character", na.strings = c("", "."), check.names = FALSE)
    values <- as.data.table(source[, c(6L, columns)])
    setnames(values, c("logrecno", sprintf("%s_%03d%s", table_id, table_lines[[table_id]], toupper(kind))))
    # One ACS estimate/MOE record per LOGRECNO; all selected geographies must match.
    stopifnot(!anyDuplicated(values$logrecno), all(header$logrecno %in% values$logrecno))
    for (column in names(values)[-1]) {
      values[, (column) := as.numeric(get(column))]
      stopifnot(all(is.na(values[[column]]) | values[[column]] >= 0))
    }
    demographics <- merge(demographics, values, by = "logrecno", all.x = TRUE, sort = FALSE)
    stopifnot(nrow(demographics) == nrow(header))
  }
}
# Shares use their table's stated universe. Undefined ratios remain missing.
demographics[, `:=`(
  white_pct = 100 * B03002_003E / fifelse(B03002_001E > 0, B03002_001E, NA_real_),
  black_pct = 100 * B03002_004E / fifelse(B03002_001E > 0, B03002_001E, NA_real_),
  hispanic_pct = 100 * B03002_012E / fifelse(B03002_001E > 0, B03002_001E, NA_real_),
  college_pct = 100 * (B15003_022E + B15003_023E + B15003_024E + B15003_025E) /
    fifelse(B15003_001E > 0, B15003_001E, NA_real_),
  poverty_pct = 100 * (C17002_002E + C17002_003E) / fifelse(C17002_001E > 0, C17002_001E, NA_real_),
  unemployment_pct = 100 * B23025_005E / fifelse(B23025_003E > 0, B23025_003E, NA_real_),
  renter_pct = 100 * B25003_003E / fifelse(B25003_001E > 0, B25003_001E, NA_real_),
  vacancy_pct = 100 * B25002_003E / fifelse(B25002_001E > 0, B25002_001E, NA_real_),
  income_censored = B19013_001E %in% c(2499, 200001),
  median_household_income = fifelse(B19013_001E %in% c(2499, 200001), NA_real_, B19013_001E)
)]
shares <- as.matrix(demographics[, .(white_pct, black_pct, hispanic_pct, college_pct,
                                   poverty_pct, unemployment_pct, renter_pct, vacancy_pct)])
stopifnot(all(is.na(shares) | (shares >= 0 & shares <= 100)))

tracts <- st_read("/vsizip/../input/tl_2012_17_tract.zip/tl_2012_17_tract.shp", quiet = TRUE)
blocks <- st_read("/vsizip/../input/tl_2012_17_bg.zip/tl_2012_17_bg.shp", quiet = TRUE)
tracts <- st_transform(tracts[tracts$COUNTYFP == "031", ], 3435)
blocks <- st_transform(blocks[blocks$COUNTYFP == "031", ], 3435)
stopifnot(all(st_is_valid(tracts)), all(st_is_valid(blocks)),
          !anyDuplicated(tracts$GEOID), !anyDuplicated(blocks$GEOID),
          setequal(header[geography == "tract", geoid], tracts$GEOID),
          setequal(header[geography == "block_group", geoid], blocks$GEOID))
# One ACS geography to one matching-vintage TIGER geography. ALAND is square meters.
land <- rbind(data.table(geoid = tracts$GEOID, land_sq_m = tracts$ALAND),
              data.table(geoid = blocks$GEOID, land_sq_m = blocks$ALAND))
stopifnot(!anyDuplicated(land$geoid))
demographics <- merge(demographics, land, by = "geoid", all.x = TRUE)
demographics[, population_per_sq_mile := B03002_001E /
               fifelse(land_sq_m > 0, land_sq_m / 2589988.110336, NA_real_)]
setorder(demographics, geography, geoid)
fwrite(demographics, "../output/baseline_demographics.csv")

sales <- fread("../input/home_sales_2008_2018.csv", select = c("row_id", "sale_year"),
               colClasses = c(row_id = "character"))
connection <- dbConnect(duckdb(), dbdir = ":memory:")
exposure <- as.data.table(dbGetQuery(connection, "
  SELECT CAST(row_id AS VARCHAR) AS row_id, focal_exposure_025,
    nearest_treated_site_id, nearest_control_site_id
  FROM read_parquet('../input/home_school_exposure_2006_2025.parquet')
  WHERE focal_exposure_025 IN ('treated_only', 'control_only')
    AND n_welcoming_schools_025 = 0 AND n_other_candidate_sites_025 = 0
"))
dbDisconnect(connection, shutdown = TRUE)
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(exposure$row_id))
# Keep quarter-mile treated-only and control-only sales, excluding nearby
# welcoming schools and candidate schools outside the 30/49 comparison.
homes <- merge(sales, exposure, by = "row_id")
homes[, `:=`(treated = as.integer(focal_exposure_025 == "treated_only"),
  school_site_id = fifelse(focal_exposure_025 == "treated_only", nearest_treated_site_id, nearest_control_site_id))]
coordinates <- fread("../input/geocoded_master_home_transactions_2006_2025.csv",
  select = c("row_id", "longitude", "latitude"), colClasses = c(row_id = "character"))
stopifnot(!anyDuplicated(coordinates$row_id), all(homes$row_id %in% coordinates$row_id))
homes <- merge(homes, coordinates, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(nrow(homes) == 10921L, uniqueN(homes[treated == 1, school_site_id]) == 29L,
          uniqueN(homes[treated == 0, school_site_id]) == 48L,
          !anyNA(homes$longitude), !anyNA(homes$latitude))
points <- st_transform(st_as_sf(homes, coords = c("longitude", "latitude"), crs = 4326), 3435)
# One home point must fall inside exactly one polygon at each geography level.
# Fail on unmatched or boundary-ambiguous points; never choose a nearest tract.
tract_matches <- st_intersects(points, tracts)
block_matches <- st_intersects(points, blocks)
stopifnot(all(lengths(tract_matches) == 1L), all(lengths(block_matches) == 1L))
homes[, `:=`(tract_geoid = tracts$GEOID[unlist(tract_matches)],
             block_group_geoid = blocks$GEOID[unlist(block_matches)])]
stopifnot(all(substr(homes$block_group_geoid, 1, 11) == homes$tract_geoid))
homes <- homes[, .(row_id, sale_year, treated, school_site_id, tract_geoid, block_group_geoid)]
setorder(homes, row_id)
fwrite(homes, "../output/home_census_geographies.csv")

# Summarize the saved neighborhood characteristics and home-to-Census matches.
for (dataset in c("baseline_demographics", "home_census_geographies")) {
  saved <- fread(sprintf("../output/%s.csv", dataset), colClasses = "character")
  stopifnot(!anyDuplicated(saved[[if (dataset == "baseline_demographics") "geoid" else "row_id"]]))
  schema <- data.table(column = names(saved),
    nonmissing = vapply(saved, function(x) sum(!is.na(x) & x != ""), integer(1)),
    distinct_nonmissing = vapply(saved, function(x) uniqueN(x[!is.na(x) & x != ""]), integer(1)))
  numeric_saved <- if (dataset == "baseline_demographics") {
    fread("../output/baseline_demographics.csv", colClasses = c(geoid = "character", logrecno = "character"))
  } else {
    fread("../output/home_census_geographies.csv", colClasses = c(row_id = "character",
      school_site_id = "character", tract_geoid = "character", block_group_geoid = "character"))
  }
  schema[, type := vapply(numeric_saved, function(x) paste(class(x), collapse = "/"), character(1))]
  report <- c(paste(dataset, "first verified baseline; ACS 2008–2012 and TIGER 2012"),
    paste("Rows:", nrow(saved)), "One point to exactly one tract and one block group; no nearest-geography fallback.",
    capture.output(print(schema, nrows = nrow(schema))),
    capture.output(summary(numeric_saved)),
    paste("CSV SHA256:", digest(sprintf("../output/%s.csv", dataset), algo = "sha256", file = TRUE)))
  if (dataset == "baseline_demographics") {
    for (sequence_id in c("0005", "0043", "0049", "0058", "0078", "0102")) {
      report <- c(report, paste("ACS sequence", sequence_id, "SHA256:",
        digest(sprintf("../input/20125il%s000.zip", sequence_id), algo = "sha256", file = TRUE)))
    }
    report <- c(report,
      "Income censor codes: 2,499 means 2,500 or less; 200,001 means 200,000 or more.",
      "Source MOEs are 90% margins for cells, not derived shares or balance differences.",
      paste("Geographic header SHA256:", digest("../input/g20125il.csv", algo = "sha256", file = TRUE)),
      paste("Sequence lookup SHA256:", digest("../input/sequence_lookup.txt", algo = "sha256", file = TRUE)),
      paste("TIGER tract SHA256:", digest("../input/tl_2012_17_tract.zip", algo = "sha256", file = TRUE)),
      paste("TIGER block group SHA256:", digest("../input/tl_2012_17_bg.zip", algo = "sha256", file = TRUE)))
  }
  writeLines(trimws(report, which = "right"), sprintf("../report/%s.txt", dataset))
}
print(homes[, .(sales = .N, sites = uniqueN(school_site_id), tracts = uniqueN(tract_geoid),
                block_groups = uniqueN(block_group_geoid)), by = treated])
