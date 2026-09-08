# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_rings/code")
suppressPackageStartupMessages({library(data.table); library(DBI); library(duckdb); library(arrow); library(digest)})
sales <- fread("../input/home_sales_2008_2018.csv", select = c("row_id", "pin", "sale_year",
  "sale_price_real_2022", "res_char_bldg_sf", "analysis_class"), colClasses = c(row_id = "character", pin = "character"))
stopifnot(!anyDuplicated(sales$row_id))
connection <- dbConnect(duckdb(), dbdir = ":memory:")
dbWriteTable(connection, "clean_ids", as.data.frame(sales[, .(row_id)]))
# One distance row per (transaction, physical school location). Rank only the
# 29 treated and 49 control physical sites; missing centroids remain missing.
nearest <- as.data.table(dbGetQuery(connection, "
  WITH ranked AS (
    SELECT CAST(d.row_id AS VARCHAR) AS row_id, d.school_location_id,
      d.housing_treat_30, d.distance_feet,
      row_number() OVER (PARTITION BY d.row_id ORDER BY distance_feet, school_location_id) AS rank
    FROM read_parquet('../input/home_school_distances_2006_2025.parquet') d
    JOIN clean_ids c ON CAST(d.row_id AS VARCHAR) = c.row_id
    WHERE school_location_role = 'candidate_site'
      AND (housing_treat_30 = 1 OR housing_control_49 = 1)
  )
  SELECT row_id, max(school_location_id) FILTER (WHERE rank=1) AS school_site_id,
    max(housing_treat_30) FILTER (WHERE rank=1) AS treated,
    max(distance_feet) FILTER (WHERE rank=1) AS distance_feet,
    max(distance_feet) FILTER (WHERE rank=2) AS second_site_distance_feet,
    count(*) AS focal_sites
  FROM ranked GROUP BY row_id
"))
exposure <- as.data.table(dbGetQuery(connection, "
  SELECT CAST(e.row_id AS VARCHAR) AS row_id, nearest_welcoming_school_distance_feet,
    nearest_other_candidate_site_distance_feet, nearest_treated_site_distance_feet,
    nearest_control_site_distance_feet
  FROM read_parquet('../input/home_school_exposure_2006_2025.parquet') e
  JOIN clean_ids c ON CAST(e.row_id AS VARCHAR) = c.row_id
"))
dbDisconnect(connection, shutdown = TRUE)
# One clean sale to one nearest-site record and one existing exposure record.
stopifnot(!anyDuplicated(nearest$row_id), !anyDuplicated(exposure$row_id),
          setequal(sales$row_id, nearest$row_id), setequal(sales$row_id, exposure$row_id),
          all(nearest$focal_sites == 78L))
sales <- merge(merge(sales, nearest, by = "row_id"), exposure, by = "row_id")
stopifnot(all(is.na(sales$distance_feet) | sales$distance_feet <= sales$second_site_distance_feet),
          all(is.na(sales$distance_feet) | abs(sales$distance_feet - pmin(
            sales$nearest_treated_site_distance_feet, sales$nearest_control_site_distance_feet)) < 1e-8))
# Compare three non-overlapping distance bands and two cumulative buffers.
rings <- data.table(ring = c("within_0125", "annulus_0125_025", "annulus_025_05", "within_025", "within_05"),
  inner_miles = c(0, .125, .25, 0, 0), outer_miles = c(.125, .25, .5, .25, .5))
assignments <- list()
summaries <- list()
for (index in seq_len(nrow(rings))) {
  inner <- rings$inner_miles[index] * 5280
  outer <- rings$outer_miles[index] * 5280
  candidate <- sales[!is.na(distance_feet) & distance_feet <= outer &
                       (if (inner == 0) distance_feet >= 0 else distance_feet > inner)]
  candidate[, overlap := second_site_distance_feet <= outer]
  candidate[, opposite_overlap := nearest_treated_site_distance_feet <= outer & nearest_control_site_distance_feet <= outer]
  candidate[, competing := nearest_welcoming_school_distance_feet <= outer | nearest_other_candidate_site_distance_feet <= outer]
  selected <- candidate[!overlap & !competing]
  stopifnot(!anyDuplicated(selected$row_id), all(selected$second_site_distance_feet > outer),
            all(selected$nearest_welcoming_school_distance_feet > outer),
            all(selected$nearest_other_candidate_site_distance_feet > outer))
  site_support <- selected[, .(pre = sum(sale_year <= 2012), post = sum(sale_year >= 2014)), by = .(school_site_id, treated)]
  # Report sites with no eligible sales before or after 2013 in each band.
  for (status in 0:1) {
    group <- selected[treated == status]
    baseline <- group[sale_year <= 2012]
    summaries[[length(summaries) + 1L]] <- data.table(ring = rings$ring[index],
      inner_miles = rings$inner_miles[index], outer_miles = rings$outer_miles[index], treated = status,
      before_exclusions = candidate[treated == status, .N],
      opposite_overlap = candidate[treated == status, sum(opposite_overlap)],
      same_status_only_overlap = candidate[treated == status, sum(overlap & !opposite_overlap)],
      welcoming_other_after_overlap = candidate[treated == status, sum(!overlap & competing)],
      sales = nrow(group), parcels = uniqueN(group$pin), sites = uniqueN(group$school_site_id),
      sites_without_pre = site_support[treated == status, sum(pre == 0)],
      sites_without_post = site_support[treated == status, sum(post == 0)],
      pre_sales = nrow(baseline), transition_sales = group[sale_year == 2013, .N], post_sales = group[sale_year >= 2014, .N],
      pre_mean_price = mean(baseline$sale_price_real_2022), pre_median_price = median(baseline$sale_price_real_2022),
      pre_mean_sqft = mean(baseline$res_char_bldg_sf), pre_class_211_pct = 100 * mean(baseline$analysis_class == 211L))
  }
  assignments[[index]] <- selected[, .(ring = rings$ring[index], row_id, school_site_id, treated, distance_feet)]
}
assignments <- rbindlist(assignments)
summaries <- rbindlist(summaries)
stopifnot(!anyDuplicated(assignments[, .(ring, row_id)]),
          all(summaries$before_exclusions - summaries$opposite_overlap - summaries$same_status_only_overlap -
                summaries$welcoming_other_after_overlap == summaries$sales))
setorder(assignments, ring, row_id)
write_parquet(assignments, "../output/ring_assignments.parquet")
fwrite(summaries, "../output/sample_summary.csv")
saved <- as.data.table(read_parquet("../output/ring_assignments.parquet"))
stopifnot(identical(assignments, saved), !anyNA(saved))
schema <- data.table(column = names(saved), type = vapply(saved, function(x) paste(class(x), collapse = "/"), character(1)),
  nonmissing = vapply(saved, function(x) sum(!is.na(x)), integer(1)),
  distinct = vapply(saved, uniqueN, integer(1)))
report <- c("Ring assignments: first verified baseline", "Key: ring, row_id; one transaction per specification.",
  "Same 30/49 school flags; exclude any second focal site plus welcoming/other candidates within the outer radius.",
  paste("Rows:", nrow(saved)), capture.output(print(schema)), capture.output(summary(saved)),
  capture.output(print(summaries)),
  paste("Parquet SHA256:", digest("../output/ring_assignments.parquet", file = TRUE, algo = "sha256")))
writeLines(trimws(report, which = "right"), "../report/ring_assignments.txt")
print(summaries)
