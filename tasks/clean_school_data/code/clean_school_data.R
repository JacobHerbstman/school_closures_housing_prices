library(dplyr)
library(janitor)
library(readr)
library(tidyr)

closure_1213 <- read_csv(
  "../input/Elementary_Closure_SY1213_Chicago.csv",
  show_col_types = FALSE
) |>
  clean_names()

attendance_1213 <- read_csv(
  "../input/Elementary_Attendance_SY1213_Chicago.csv",
  show_col_types = FALSE
) |>
  clean_names()

report_1213 <- read_csv(
  "../input/Elementary_Report_Card_SY1213_Chicago.csv",
  show_col_types = FALSE
) |>
  clean_names()

report_1112 <- read_csv(
  "../input/All_Schools_Report_Card_SY1112_Chicago.csv",
  show_col_types = FALSE
) |>
  clean_names()

report_1314 <- read_csv(
  "../input/Elementary_Report_Card_SY1314_Chicago.csv",
  show_col_types = FALSE
) |>
  clean_names()

stopifnot(
  nrow(closure_1213) == 129L,
  n_distinct(closure_1213$school_id) == 129L,
  !anyDuplicated(report_1213$school_id)
)

collapse_boundary <- function(x) {
  paste(replace_na(as.character(x), "NA"), collapse = " || ")
}

attendance_1213_school <- attendance_1213 |>
  select(school_id, the_geom, shape_leng, shape_area, boundarygr) |>
  group_by(school_id) |>
  summarise(
    n_boundary_records = n(),
    across(
      c(the_geom, shape_leng, shape_area, boundarygr),
      collapse_boundary
    ),
    .groups = "drop"
  ) |>
  rename_with(~ paste0(.x, "_sy1213"), -school_id)

report_1213_school <- report_1213 |>
  select(
    -any_of(
      c(
        "unit_id",
        "school_short_name",
        "location",
        "city",
        "state",
        "grade_cat",
        "brd_rpt",
        "sch_type",
        "blue_ribbon_award",
        "blue_ribbon_award_year"
      )
    )
  ) |>
  rename(
    latitude_sy1213 = longitude,
    longitude_sy1213 = latitude
  ) |>
  rename_with(
    ~ paste0(.x, "_sy1213"),
    -c(school_id, latitude_sy1213, longitude_sy1213)
  )

school_1213 <- closure_1213 |>
  mutate(
    report_card_match_sy1213 = school_id %in% report_1213$school_id,
    attendance_boundary_match_sy1213 = school_id %in% attendance_1213$school_id
  ) |>
  left_join(report_1213_school, by = "school_id") |>
  left_join(attendance_1213_school, by = "school_id")

stopifnot(
  nrow(school_1213) == 129L,
  n_distinct(school_1213$school_id) == 129L,
  sum(school_1213$report_card_match_sy1213) == 125L,
  sum(school_1213$attendance_boundary_match_sy1213) == 115L,
  sum(
    school_1213$report_card_match_sy1213 &
      school_1213$attendance_boundary_match_sy1213
  ) == 115L
)

school_1213_clean <- school_1213 |>
  select(-any_of(c("school_nm", "school_add"))) |>
  select(
    school_id,
    school_name_sy1213,
    feb2013_candidate_129,
    mar2013_candidate_54,
    may2013_closed_47,
    may2013_welcoming_18,
    consortium_treat_47,
    consortium_control_49,
    housing_treat_30,
    housing_control_49,
    notes,
    street_address_sy1213,
    zip_sy1213,
    x_coordinate_sy1213,
    y_coordinate_sy1213,
    latitude_sy1213,
    longitude_sy1213,
    attendance_boundary_match_sy1213,
    n_boundary_records_sy1213,
    boundarygr_sy1213,
    the_geom_sy1213,
    shape_leng_sy1213,
    shape_area_sy1213,
    everything()
  )

school_info_1112 <- report_1112 |>
  filter(school_id %in% c(610085, 610075, 610280)) |>
  transmute(
    school_id,
    school_name_sy1213 = name_of_school,
    street_address_sy1213 = street_address,
    zip_sy1213 = zip_code,
    x_coordinate_sy1213 = x_coordinate,
    y_coordinate_sy1213 = y_coordinate,
    latitude_sy1213 = latitude,
    longitude_sy1213 = longitude
  )

stopifnot(nrow(school_info_1112) == 3L, !anyDuplicated(school_info_1112$school_id))

school_1213_clean <- school_1213_clean |>
  mutate(
    school_name_sy1213 = if_else(
      school_id %in% c(610085, 610075, 610280),
      NA_character_,
      school_name_sy1213
    )
  ) |>
  rows_patch(school_info_1112, by = "school_id")

# Garfield Park and Faraday occupied the same CPS facility. This reproduces
# Noah's substitution of Faraday's SY2012–13 location for Garfield Park.
school_info_garfield <- report_1213 |>
  filter(school_id == 610055) |>
  transmute(
    school_id = 400095,
    school_name_sy1213 =
      "Garfield Park Preparatory Academy Elementary School",
    street_address_sy1213 = "3250 W Monroe St",
    zip_sy1213 = zip,
    x_coordinate_sy1213 = x_coordinate,
    y_coordinate_sy1213 = y_coordinate,
    latitude_sy1213 = longitude,
    longitude_sy1213 = latitude
  )

stopifnot(nrow(school_info_garfield) == 1L)

school_1213_clean <- school_1213_clean |>
  rows_update(school_info_garfield, by = "school_id")

report_1314_school <- report_1314 |>
  distinct(school_id, .keep_all = TRUE)

school_info_1314 <- report_1314_school |>
  transmute(
    school_id,
    school_name_sy1314 = name_of_school,
    street_address_sy1314 = street_address,
    zip_sy1314 = zip_code,
    x_coordinate_sy1314 = x_coordinate,
    y_coordinate_sy1314 = y_coordinate,
    latitude_sy1314 = latitude,
    longitude_sy1314 = longitude
  )

school_1213_clean <- school_1213_clean |>
  mutate(report_card_match_sy1314 = school_id %in% school_info_1314$school_id) |>
  left_join(school_info_1314, by = "school_id")

welcoming_info_1314 <- report_1314_school |>
  select(
    school_id,
    name_of_school,
    street_address,
    x_coordinate,
    y_coordinate,
    latitude,
    longitude
  )

for (i in 1:3) {
  id_var <- paste0("welcoming_school_id", i)
  old_vars <- c(
    paste0("welcoming_school_nm", i),
    paste0("welcoming_school_add", i, "_sy1314"),
    paste0("welcoming_school_x_coordinate", i, "_sy1314"),
    paste0("welcoming_school_y_coordinate", i, "_sy1314"),
    paste0("welcoming_school_latitude", i, "_sy1314"),
    paste0("welcoming_school_longitude", i, "_sy1314")
  )

  welcoming_info_i <- welcoming_info_1314 |>
    transmute(
      !!id_var := school_id,
      !!paste0("welcoming_school_name", i, "_sy1314") := name_of_school,
      !!paste0("welcoming_school_street_address", i, "_sy1314") := street_address,
      !!paste0("welcoming_school_x_coordinate", i, "_sy1314") := x_coordinate,
      !!paste0("welcoming_school_y_coordinate", i, "_sy1314") := y_coordinate,
      !!paste0("welcoming_school_latitude", i, "_sy1314") := latitude,
      !!paste0("welcoming_school_longitude", i, "_sy1314") := longitude
    )

  school_1213_clean <- school_1213_clean |>
    select(-any_of(old_vars)) |>
    left_join(welcoming_info_i, by = id_var)
}

school_closure_clean <- school_1213_clean |>
  relocate(
    report_card_match_sy1314,
    school_name_sy1314,
    street_address_sy1314,
    zip_sy1314,
    x_coordinate_sy1314,
    y_coordinate_sy1314,
    latitude_sy1314,
    longitude_sy1314,
    .after = longitude_sy1213
  ) |>
  relocate(
    welcoming_school_id1,
    welcoming_school_name1_sy1314,
    welcoming_school_street_address1_sy1314,
    welcoming_school_x_coordinate1_sy1314,
    welcoming_school_y_coordinate1_sy1314,
    welcoming_school_latitude1_sy1314,
    welcoming_school_longitude1_sy1314,
    welcoming_school_id2,
    welcoming_school_name2_sy1314,
    welcoming_school_street_address2_sy1314,
    welcoming_school_x_coordinate2_sy1314,
    welcoming_school_y_coordinate2_sy1314,
    welcoming_school_latitude2_sy1314,
    welcoming_school_longitude2_sy1314,
    welcoming_school_id3,
    welcoming_school_name3_sy1314,
    welcoming_school_street_address3_sy1314,
    welcoming_school_x_coordinate3_sy1314,
    welcoming_school_y_coordinate3_sy1314,
    welcoming_school_latitude3_sy1314,
    welcoming_school_longitude3_sy1314,
    .after = shape_area_sy1213
  ) |>
  group_by(x_coordinate_sy1213, y_coordinate_sy1213) |>
  mutate(
    school_site_id = min(school_id),
    n_candidate_schools_at_site = n()
  ) |>
  ungroup() |>
  relocate(school_site_id, n_candidate_schools_at_site, .after = school_id)

school_sites <- school_closure_clean |>
  distinct(school_site_id, housing_treat_30, housing_control_49)

stopifnot(
  nrow(school_closure_clean) == 129L,
  !anyDuplicated(school_closure_clean$school_id),
  n_distinct(school_closure_clean$school_site_id) == 127L,
  nrow(school_sites) == 127L,
  sum(school_sites$housing_treat_30 == 1L) == 29L,
  sum(school_sites$housing_control_49 == 1L) == 49L,
  !any(school_sites$housing_treat_30 == 1L &
         school_sites$housing_control_49 == 1L)
)

write_csv(
  school_closure_clean,
  "../output/Elementary_Closure_SY1213_Chicago_Clean.csv"
)
