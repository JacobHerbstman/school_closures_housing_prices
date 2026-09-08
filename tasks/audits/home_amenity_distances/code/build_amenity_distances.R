# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_amenity_distances/code")

suppressPackageStartupMessages({library(data.table); library(sf); library(jsonlite); library(digest)})

sales <- fread("../input/home_sales_2008_2018.csv", select = "row_id", colClasses = c(row_id = "character"))
coordinates <- fread("../input/geocoded_master_home_transactions_2006_2025.csv",
  select = c("row_id", "centroid_x_crs_3435", "centroid_y_crs_3435"), colClasses = c(row_id = "character"))
# One clean transaction to one geocoded-master row; preserve missing coordinates.
stopifnot(!anyDuplicated(sales$row_id), !anyDuplicated(coordinates$row_id),
          all(sales$row_id %in% coordinates$row_id))
homes <- merge(sales, coordinates, by = "row_id", all.x = TRUE, sort = FALSE)
stopifnot(nrow(homes) == nrow(sales),
          identical(is.na(homes$centroid_x_crs_3435), is.na(homes$centroid_y_crs_3435)))

park_metadata <- fromJSON("../input/parks_metadata.json")
cta_metadata <- fromJSON("../input/cta_metadata.json")
stopifnot(park_metadata$blobFilename == "Parks_Aug2012.zip",
          grepl("March 2013", cta_metadata$description), grepl("2012", cta_metadata$description))
parks <- st_read("/vsizip/../input/parks_aug2012.zip/Parks_Aug2012.shp", quiet = TRUE)
cta <- st_read("../input/cta_2012.geojson", quiet = TRUE)
water <- st_read("../input/chicago_hydro.geojson", quiet = TRUE)
stopifnot(st_crs(parks)$epsg == 3435L, st_crs(cta)$epsg == 4326L,
          st_crs(water)$epsg == 4326L, nrow(parks) == 583L, nrow(cta) == 145L,
          !anyDuplicated(cta$GTFS), all(c(41510L, 41680L) %in% cta$GTFS),
          !41700L %in% cta$GTFS)
parks <- st_transform(parks, 3435)
cta <- st_transform(cta, 3435)
lake <- st_transform(water[!is.na(water$name) & water$name == "LAKE MICHIGAN", ], 3435)
stopifnot(nrow(lake) == 1L, lake$edit_date1 == "10-14-05", all(st_is_valid(lake)),
          all(st_is_valid(cta)), !any(st_is_empty(cta)))
invalid_parks <- which(!st_is_valid(parks))
stopifnot(length(invalid_parks) == 1L, parks$PARK_NO[invalid_parks] == 218L)
parks[invalid_parks, ] <- st_make_valid(parks[invalid_parks, ])
stopifnot(all(st_is_valid(parks)), !any(st_is_empty(parks)))

located <- which(complete.cases(homes[, .(centroid_x_crs_3435, centroid_y_crs_3435)]))
points <- st_as_sf(homes[located], coords = c("centroid_x_crs_3435", "centroid_y_crs_3435"), crs = 3435)
stopifnot(all(st_is_valid(points)), !any(st_is_empty(points)))
nearest_park <- st_nearest_feature(points, parks)
nearest_cta <- st_nearest_feature(points, cta)
homes[, `:=`(lake_miles = NA_real_, park_miles = NA_real_, cta_miles = NA_real_)]
homes[located, `:=`(
  lake_miles = as.numeric(st_distance(points, st_boundary(lake))) / 5280,
  park_miles = as.numeric(st_distance(points, parks[nearest_park, ], by_element = TRUE)) / 5280,
  cta_miles = as.numeric(st_distance(points, cta[nearest_cta, ], by_element = TRUE)) / 5280
)]
stopifnot(all(is.finite(as.matrix(homes[located, .(lake_miles, park_miles, cta_miles)]))),
          all(as.matrix(homes[located, .(lake_miles, park_miles, cta_miles)]) >= 0),
          max(homes$lake_miles, na.rm = TRUE) < 30,
          max(homes$park_miles, na.rm = TRUE) < 5,
          max(homes$cta_miles, na.rm = TRUE) < 20)
distances <- homes[, .(row_id, lake_miles, park_miles, cta_miles)]
setorder(distances, row_id)
fwrite(distances, "../output/home_amenity_distances.csv")

# Report the saved transaction-level dataset, including retained missingness.
saved <- fread("../output/home_amenity_distances.csv", colClasses = c(row_id = "character"))
stopifnot(!anyNA(saved$row_id), !anyDuplicated(saved$row_id), nrow(saved) == nrow(sales))
schema <- data.table(column = names(saved), type = vapply(saved, function(x) paste(class(x), collapse = "/"), character(1)),
  nonmissing = vapply(saved, function(x) sum(!is.na(x)), integer(1)),
  distinct_nonmissing = vapply(saved, function(x) uniqueN(x[!is.na(x)]), integer(1)))
report <- c("Home amenity distances: first verified baseline", "Key: row_id; one row per clean price transaction",
  paste("Rows:", nrow(saved)), "Distance units: miles (5,280 EPSG:3435 US survey feet)",
  "Source features: 583 park polygons, 145 CTA stations, one Lake Michigan polygon",
  "Geometry repair: st_make_valid on park 218 (Douglas), one ring self-intersection",
  capture.output(print(schema)), capture.output(summary(saved[, .(lake_miles, park_miles, cta_miles)])),
  paste("CSV SHA256:", digest("../output/home_amenity_distances.csv", algo = "sha256", file = TRUE)),
  paste("Parks ZIP SHA256:", digest("../input/parks_aug2012.zip", algo = "sha256", file = TRUE)),
  paste("CTA GeoJSON SHA256:", digest("../input/cta_2012.geojson", algo = "sha256", file = TRUE)),
  paste("Hydro GeoJSON SHA256:", digest("../input/chicago_hydro.geojson", algo = "sha256", file = TRUE)))
writeLines(trimws(report, which = "right"), "../report/home_amenity_distances.txt")
cat(paste(report, collapse = "\n"), "\n")
