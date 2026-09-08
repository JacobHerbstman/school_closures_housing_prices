# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/build_home_school_exposure/code")

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

connection <- dbConnect(duckdb(), dbdir = ":memory:")
# Keep Parquet row-group construction deterministic across identical rebuilds.
dbExecute(connection, "SET threads = 1")

rows_written <- dbExecute(connection, "
  COPY (
    WITH nearest_locations AS (
      SELECT
        row_id,
        arg_min(
          school_location_id,
          (distance_feet, school_location_id)
        ) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 1
            AND distance_feet IS NOT NULL
        ) AS nearest_treated_site_id,
        min(distance_feet) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 1
        ) AS nearest_treated_site_distance_feet,
        arg_min(
          school_location_id,
          (distance_feet, school_location_id)
        ) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_control_49 = 1
            AND distance_feet IS NOT NULL
        ) AS nearest_control_site_id,
        min(distance_feet) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_control_49 = 1
        ) AS nearest_control_site_distance_feet,
        arg_min(
          school_location_id,
          (distance_feet, school_location_id)
        ) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 0
            AND housing_control_49 = 0
            AND distance_feet IS NOT NULL
        ) AS nearest_other_candidate_site_id,
        min(distance_feet) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 0
            AND housing_control_49 = 0
        ) AS nearest_other_candidate_site_distance_feet,
        arg_min(
          school_location_id,
          (distance_feet, school_location_id)
        ) FILTER (
          WHERE school_location_role = 'welcoming_school'
            AND distance_feet IS NOT NULL
        ) AS nearest_welcoming_school_id,
        min(distance_feet) FILTER (
          WHERE school_location_role = 'welcoming_school'
        ) AS nearest_welcoming_school_distance_feet,
        count(*) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 1
            AND distance_feet <= 1320
        ) AS n_treated_sites_025,
        count(*) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_control_49 = 1
            AND distance_feet <= 1320
        ) AS n_control_sites_025,
        count(*) FILTER (
          WHERE school_location_role = 'candidate_site'
            AND housing_treat_30 = 0
            AND housing_control_49 = 0
            AND distance_feet <= 1320
        ) AS n_other_candidate_sites_025,
        count(*) FILTER (
          WHERE school_location_role = 'welcoming_school'
            AND distance_feet <= 1320
        ) AS n_welcoming_schools_025
      FROM read_parquet(
        '../input/home_school_distances_2006_2025.parquet'
      )
      GROUP BY row_id
    ),
    exposure AS (
      SELECT
        row_id,
        nearest_treated_site_distance_feet IS NOT NULL
          AS has_school_distances,
        nearest_treated_site_id,
        nearest_treated_site_distance_feet,
        nearest_control_site_id,
        nearest_control_site_distance_feet,
        nearest_other_candidate_site_id,
        nearest_other_candidate_site_distance_feet,
        nearest_welcoming_school_id,
        nearest_welcoming_school_distance_feet,
        CASE WHEN nearest_treated_site_distance_feet IS NULL
          THEN NULL
          ELSE CAST(n_treated_sites_025 AS INTEGER)
        END AS n_treated_sites_025,
        CASE WHEN nearest_treated_site_distance_feet IS NULL
          THEN NULL
          ELSE CAST(n_control_sites_025 AS INTEGER)
        END AS n_control_sites_025,
        CASE WHEN nearest_treated_site_distance_feet IS NULL
          THEN NULL
          ELSE CAST(n_other_candidate_sites_025 AS INTEGER)
        END AS n_other_candidate_sites_025,
        CASE WHEN nearest_treated_site_distance_feet IS NULL
          THEN NULL
          ELSE CAST(n_welcoming_schools_025 AS INTEGER)
        END AS n_welcoming_schools_025
      FROM nearest_locations
    )
    SELECT
      *,
      CASE
        WHEN NOT has_school_distances THEN 'missing_coordinates'
        WHEN n_treated_sites_025 > 0 AND n_control_sites_025 = 0
          THEN 'treated_only'
        WHEN n_treated_sites_025 = 0 AND n_control_sites_025 > 0
          THEN 'control_only'
        WHEN n_treated_sites_025 > 0 AND n_control_sites_025 > 0
          THEN 'treated_control_overlap'
        ELSE 'outside_focal_rings'
      END AS focal_exposure_025
    FROM exposure
    ORDER BY row_id
  ) TO '../output/home_school_exposure_2006_2025.parquet'
  (FORMAT PARQUET, COMPRESSION ZSTD, OVERWRITE_OR_IGNORE TRUE)
")

checks <- dbGetQuery(connection, "
  SELECT
    count(*) AS rows,
    count(DISTINCT row_id) AS row_ids,
    count(*) FILTER (WHERE NOT has_school_distances) AS missing_coordinates,
    count(*) FILTER (
      WHERE has_school_distances
        AND (
          nearest_treated_site_id IS NULL
          OR nearest_treated_site_distance_feet IS NULL
          OR nearest_control_site_id IS NULL
          OR nearest_control_site_distance_feet IS NULL
          OR nearest_other_candidate_site_id IS NULL
          OR nearest_other_candidate_site_distance_feet IS NULL
          OR nearest_welcoming_school_id IS NULL
          OR nearest_welcoming_school_distance_feet IS NULL
          OR nearest_treated_site_distance_feet < 0
          OR nearest_control_site_distance_feet < 0
          OR nearest_other_candidate_site_distance_feet < 0
          OR nearest_welcoming_school_distance_feet < 0
          OR n_treated_sites_025 IS NULL
          OR n_control_sites_025 IS NULL
          OR n_other_candidate_sites_025 IS NULL
          OR n_welcoming_schools_025 IS NULL
        )
    ) AS invalid_complete_rows,
    count(*) FILTER (
      WHERE NOT has_school_distances
        AND (
          nearest_treated_site_id IS NOT NULL
          OR nearest_treated_site_distance_feet IS NOT NULL
          OR nearest_control_site_id IS NOT NULL
          OR nearest_control_site_distance_feet IS NOT NULL
          OR nearest_other_candidate_site_id IS NOT NULL
          OR nearest_other_candidate_site_distance_feet IS NOT NULL
          OR nearest_welcoming_school_id IS NOT NULL
          OR nearest_welcoming_school_distance_feet IS NOT NULL
          OR n_treated_sites_025 IS NOT NULL
          OR n_control_sites_025 IS NOT NULL
          OR n_other_candidate_sites_025 IS NOT NULL
          OR n_welcoming_schools_025 IS NOT NULL
        )
    ) AS invalid_missing_rows
  FROM read_parquet(
    '../output/home_school_exposure_2006_2025.parquet'
  )
")

stopifnot(
  rows_written == 428582,
  checks$rows == 428582,
  checks$row_ids == 428582,
  checks$missing_coordinates == 6,
  checks$invalid_complete_rows == 0,
  checks$invalid_missing_rows == 0
)

exposure_counts <- dbGetQuery(connection, "
  SELECT focal_exposure_025, count(*) AS sales
  FROM read_parquet(
    '../output/home_school_exposure_2006_2025.parquet'
  )
  GROUP BY focal_exposure_025
  ORDER BY focal_exposure_025
")

stopifnot(
  sum(exposure_counts$sales) == 428582,
  setequal(
    exposure_counts$focal_exposure_025,
    c(
      "treated_only",
      "control_only",
      "treated_control_overlap",
      "outside_focal_rings",
      "missing_coordinates"
    )
  )
)

dbDisconnect(connection, shutdown = TRUE)

print(exposure_counts)
