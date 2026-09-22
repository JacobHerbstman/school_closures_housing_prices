# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/calculate_home_school_distances/code")
suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
})

home_sales <- fread(
  "../input/geocoded_master_home_transactions_2006_2025.csv",
  select = c(
    "row_id",
    "centroid_x_crs_3435",
    "centroid_y_crs_3435",
    "has_historical_coordinates"
  ),
  colClasses = list(character = "row_id")
)

schools <- fread(
  "../input/Elementary_Closure_SY1213_Chicago_Clean.csv"
)

stopifnot(
  nrow(home_sales) > 0L,
  !anyDuplicated(home_sales$row_id),
  identical(
    home_sales$has_historical_coordinates,
    complete.cases(
      home_sales[, .(centroid_x_crs_3435, centroid_y_crs_3435)]
    )
  ),
  mean(home_sales$has_historical_coordinates) >= 0.999,
  all(is.finite(
    home_sales$centroid_x_crs_3435[
      home_sales$has_historical_coordinates
    ]
  )),
  all(is.finite(
    home_sales$centroid_y_crs_3435[
      home_sales$has_historical_coordinates
    ]
  )),
  nrow(schools) == 129L,
  !anyDuplicated(schools$school_id)
)

# Candidate schools sharing a building are one location. Treatment and control
# status must agree within each location before the school rows are collapsed.
candidate_locations <- unique(
  schools[, .(
    school_location_role = "candidate_site",
    school_location_id = as.integer(school_site_id),
    school_x_crs_3435 = as.numeric(x_coordinate_sy1213),
    school_y_crs_3435 = as.numeric(y_coordinate_sy1213),
    housing_treat_30 = as.integer(housing_treat_30),
    housing_control_49 = as.integer(housing_control_49)
  )]
)

stopifnot(
  nrow(candidate_locations) == 127L,
  !anyDuplicated(candidate_locations$school_location_id),
  sum(candidate_locations$housing_treat_30 == 1L) == 29L,
  sum(candidate_locations$housing_control_49 == 1L) == 49L,
  !any(candidate_locations$housing_treat_30 == 1L &
         candidate_locations$housing_control_49 == 1L)
)

# Welcoming schools use their SY2013-14 locations. The same welcoming school
# can appear for several closed schools, so repeated assignments are collapsed.
welcoming_locations <- rbindlist(
  lapply(1:3, function(index) {
    school_id_column <- paste0("welcoming_school_id", index)
    x_column <- paste0("welcoming_school_x_coordinate", index, "_sy1314")
    y_column <- paste0("welcoming_school_y_coordinate", index, "_sy1314")

    schools[!is.na(get(school_id_column)), .(
      school_location_role = "welcoming_school",
      school_location_id = as.integer(get(school_id_column)),
      school_x_crs_3435 = as.numeric(get(x_column)),
      school_y_crs_3435 = as.numeric(get(y_column)),
      housing_treat_30 = NA_integer_,
      housing_control_49 = NA_integer_
    )]
  })
)

stopifnot(
  nrow(welcoming_locations) == 53L,
  uniqueN(welcoming_locations$school_location_id) == 48L,
  uniqueN(
    welcoming_locations,
    by = c(
      "school_location_id",
      "school_x_crs_3435",
      "school_y_crs_3435"
    )
  ) == 48L
)

welcoming_locations <- unique(
  welcoming_locations,
  by = c(
    "school_location_id",
    "school_x_crs_3435",
    "school_y_crs_3435"
  )
)

# A welcoming school that moved into a closed school's building vacated its own
# SY2012-13 building, so homes near that building also lost their school. A move
# is a SY2012-13 location more than 300 feet from the SY2013-14 location.
welcoming_moves <- unique(rbindlist(
  lapply(1:3, function(index) {
    school_id_column <- paste0("welcoming_school_id", index)
    schools[!is.na(get(school_id_column)), .(
      school_location_id = as.integer(get(school_id_column)),
      x_sy1213 = as.numeric(get(paste0("welcoming_school_x_coordinate", index, "_sy1213"))),
      y_sy1213 = as.numeric(get(paste0("welcoming_school_y_coordinate", index, "_sy1213"))),
      x_sy1314 = as.numeric(get(paste0("welcoming_school_x_coordinate", index, "_sy1314"))),
      y_sy1314 = as.numeric(get(paste0("welcoming_school_y_coordinate", index, "_sy1314")))
    )]
  })
))
stopifnot(!anyDuplicated(welcoming_moves$school_location_id), complete.cases(welcoming_moves))
vacated_locations <- welcoming_moves[
  sqrt((x_sy1213 - x_sy1314)^2 + (y_sy1213 - y_sy1314)^2) > 300,
  .(
    school_location_role = "vacated_welcoming_building",
    school_location_id,
    school_x_crs_3435 = x_sy1213,
    school_y_crs_3435 = y_sy1213,
    housing_treat_30 = NA_integer_,
    housing_control_49 = NA_integer_
  )
]

school_locations <- rbindlist(
  list(candidate_locations, welcoming_locations, vacated_locations),
  use.names = TRUE
)
setorder(school_locations, school_location_role, school_location_id)

stopifnot(
  nrow(school_locations) ==
    nrow(candidate_locations) + nrow(welcoming_locations) + nrow(vacated_locations),
  !anyDuplicated(
    school_locations[, .(school_location_role, school_location_id)]
  ),
  complete.cases(
    school_locations[, .(school_x_crs_3435, school_y_crs_3435)]
  ),
  school_locations$school_x_crs_3435 > 1000000,
  school_locations$school_x_crs_3435 < 1300000,
  school_locations$school_y_crs_3435 > 1700000,
  school_locations$school_y_crs_3435 < 2000000
)

output_file <- "../output/home_school_distances_2006_2025.parquet"
homes_per_batch <- 5000L
school_count <- nrow(school_locations)
expected_rows <- nrow(home_sales) * school_count
expected_missing_distances <- sum(!home_sales$has_historical_coordinates) *
  school_count

file_sink <- FileOutputStream$create(output_file)
parquet_writer <- NULL
rows_written <- 0
missing_distances <- 0

for (first_home in seq(1L, nrow(home_sales), by = homes_per_batch)) {
  last_home <- min(first_home + homes_per_batch - 1L, nrow(home_sales))
  home_batch <- home_sales[first_home:last_home]
  home_rows <- rep(seq_len(nrow(home_batch)), each = school_count)
  school_rows <- rep(seq_len(school_count), times = nrow(home_batch))

  distance_feet <- sqrt(
    (home_batch$centroid_x_crs_3435[home_rows] -
       school_locations$school_x_crs_3435[school_rows])^2 +
      (home_batch$centroid_y_crs_3435[home_rows] -
         school_locations$school_y_crs_3435[school_rows])^2
  )
  stopifnot(
    all(is.finite(distance_feet[!is.na(distance_feet)])),
    all(distance_feet[!is.na(distance_feet)] >= 0)
  )

  distance_batch <- record_batch(
    row_id = home_batch$row_id[home_rows],
    school_location_role =
      school_locations$school_location_role[school_rows],
    school_location_id =
      school_locations$school_location_id[school_rows],
    housing_treat_30 = school_locations$housing_treat_30[school_rows],
    housing_control_49 = school_locations$housing_control_49[school_rows],
    distance_feet = distance_feet
  )

  if (is.null(parquet_writer)) {
    writer_properties <- ParquetWriterProperties$create(
      distance_batch$schema$names,
      compression = "zstd"
    )
    parquet_writer <- ParquetFileWriter$create(
      distance_batch$schema,
      file_sink,
      properties = writer_properties
    )
  }

  parquet_writer$WriteBatch(
    distance_batch,
    chunk_size = length(distance_feet)
  )
  rows_written <- rows_written + length(distance_feet)
  missing_distances <- missing_distances + sum(is.na(distance_feet))
}

parquet_writer$Close()
file_sink$close()

parquet_file <- ParquetFileReader$create(output_file)
stopifnot(
  rows_written == expected_rows,
  missing_distances == expected_missing_distances,
  parquet_file$num_rows == expected_rows,
  parquet_file$num_columns == 6L
)

cat(sprintf(
  paste0(
    "Wrote %s distances for %s home sales and %s school locations; ",
    "%s distances are missing because %s sales lack coordinates.\n"
  ),
  format(rows_written, big.mark = ",", scientific = FALSE),
  format(nrow(home_sales), big.mark = ","),
  school_count,
  format(missing_distances, big.mark = ","),
  sum(!home_sales$has_historical_coordinates)
))
