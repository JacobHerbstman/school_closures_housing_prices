suppressPackageStartupMessages({
  library(DBI)
  library(data.table)
  library(duckdb)
})

connection <- dbConnect(duckdb(), dbdir = ":memory:")

invisible(dbExecute(connection, "
  CREATE VIEW home_sales AS
  SELECT * FROM read_csv_auto(
    '../input/home_sales_2008_2018.csv',
    header = true,
    nullstr = 'NA'
  )
"))

invisible(dbExecute(connection, "
  CREATE VIEW exposure AS
  SELECT *
  FROM read_parquet('../input/home_school_exposure_2006_2025.parquet')
"))

invisible(dbExecute(connection, "
  CREATE VIEW distances AS
  SELECT *
  FROM read_parquet('../input/home_school_distances_2006_2025.parquet')
"))

invisible(dbExecute(connection, "
  CREATE VIEW schools AS
  SELECT *
  FROM read_csv_auto(
    '../input/Elementary_Closure_SY1213_Chicago_Clean.csv',
    header = true,
    nullstr = 'NA'
  )
"))

invisible(dbExecute(connection, "
  CREATE VIEW geocoded_sales AS
  SELECT
    row_id,
    centroid_x_crs_3435,
    centroid_y_crs_3435
  FROM read_csv_auto(
    '../input/geocoded_master_home_transactions_2006_2025.csv',
    header = true,
    nullstr = 'NA'
  )
"))

integrity <- dbGetQuery(connection, "
  SELECT
    (SELECT count(*) FROM home_sales) AS sales,
    (SELECT count(DISTINCT row_id) FROM home_sales) AS sale_ids,
    (SELECT count(*)
       FROM home_sales JOIN exposure USING (row_id)) AS exposure_matches,
    (SELECT count(*)
       FROM home_sales ANTI JOIN exposure USING (row_id)) AS unmatched_sales,
    (SELECT count(DISTINCT school_location_id)
       FROM distances
       WHERE school_location_role = 'candidate_site'
         AND housing_treat_30 = 1) AS treated_sites,
    (SELECT count(DISTINCT school_location_id)
       FROM distances
       WHERE school_location_role = 'candidate_site'
         AND housing_control_49 = 1) AS control_sites
")

stopifnot(
  integrity$sales == 167468,
  integrity$sale_ids == integrity$sales,
  integrity$exposure_matches == integrity$sales,
  integrity$unmatched_sales == 0,
  integrity$treated_sites == 29,
  integrity$control_sites == 49
)

exposure_summary <- dbGetQuery(connection, "
  SELECT
    e.focal_exposure_025,
    count(*) AS sales,
    count(DISTINCT s.pin) AS parcels,
    round(100 * count(*) / sum(count(*)) OVER (), 3) AS sales_percent,
    count(*) FILTER (WHERE s.sale_year <= 2012) AS sales_2008_2012,
    count(*) FILTER (WHERE s.sale_year = 2013) AS sales_2013,
    count(*) FILTER (WHERE s.sale_year >= 2014) AS sales_2014_2018
  FROM home_sales s
  JOIN exposure e USING (row_id)
  GROUP BY e.focal_exposure_025
  ORDER BY
    CASE e.focal_exposure_025
      WHEN 'treated_only' THEN 1
      WHEN 'control_only' THEN 2
      WHEN 'treated_control_overlap' THEN 3
      WHEN 'outside_focal_rings' THEN 4
      ELSE 5
    END
")
fwrite(exposure_summary, "../output/exposure_summary.csv")

treatment_control_summary <- dbGetQuery(connection, "
  WITH analysis_samples AS (
    SELECT
      'unambiguous_focal_ring' AS sample_definition,
      s.*,
      e.* EXCLUDE (row_id)
    FROM home_sales s
    JOIN exposure e USING (row_id)
    WHERE e.focal_exposure_025 IN ('treated_only', 'control_only')

    UNION ALL

    SELECT
      'no_welcoming_or_other_candidate' AS sample_definition,
      s.*,
      e.* EXCLUDE (row_id)
    FROM home_sales s
    JOIN exposure e USING (row_id)
    WHERE e.focal_exposure_025 IN ('treated_only', 'control_only')
      AND e.n_welcoming_schools_025 = 0
      AND e.n_other_candidate_sites_025 = 0
  ),
  summary_periods AS (
    SELECT
      '2008_2018' AS summary_period,
      *
    FROM analysis_samples

    UNION ALL

    SELECT
      '2008_2012_preclosure' AS summary_period,
      *
    FROM analysis_samples
    WHERE sale_year <= 2012
  )
  SELECT
    sample_definition,
    summary_period,
    CASE focal_exposure_025
      WHEN 'treated_only' THEN 'treated'
      ELSE 'control'
    END AS exposure_group,
    count(*) AS sales,
    count(DISTINCT pin) AS parcels,
    count(DISTINCT CASE focal_exposure_025
      WHEN 'treated_only' THEN nearest_treated_site_id
      ELSE nearest_control_site_id
    END) AS nearest_school_sites,
    count(*) FILTER (WHERE sale_year <= 2012) AS sales_2008_2012,
    count(*) FILTER (WHERE sale_year = 2013) AS sales_2013,
    count(*) FILTER (WHERE sale_year >= 2014) AS sales_2014_2018,
    round(avg(sale_price_real_2022), 2) AS mean_sale_price_real_2022,
    round(median(sale_price_real_2022), 2) AS median_sale_price_real_2022,
    round(avg(price_per_building_sqft_real_2022), 2)
      AS mean_price_per_sqft_real_2022,
    round(median(price_per_building_sqft_real_2022), 2)
      AS median_price_per_sqft_real_2022,
    round(avg(res_char_bldg_sf), 2) AS mean_building_sqft,
    round(median(res_char_bldg_sf), 2) AS median_building_sqft,
    round(avg(res_char_land_sf), 2) AS mean_land_sqft,
    round(avg(sale_year - res_char_yrblt), 2) AS mean_age_at_sale,
    round(avg(res_char_beds), 2) AS mean_bedrooms,
    round(avg(res_char_rooms), 2) AS mean_rooms,
    round(avg(res_char_fbath), 2) AS mean_full_bathrooms,
    round(100 * avg(CAST(analysis_class = 211 AS INTEGER)), 2)
      AS class_211_percent,
    round(100 * avg(CAST(is_mydec_date AS INTEGER)), 2)
      AS idor_refined_date_percent,
    count(*) FILTER (WHERE n_treated_sites_025 > 1)
      AS multiple_treated_sites,
    count(*) FILTER (WHERE n_control_sites_025 > 1)
      AS multiple_control_sites
  FROM summary_periods
  GROUP BY sample_definition, summary_period, focal_exposure_025
  ORDER BY sample_definition, summary_period, exposure_group
")
fwrite(
  treatment_control_summary,
  "../output/treatment_control_summary.csv"
)

annual_real_price_summary <- dbGetQuery(connection, "
  SELECT
    s.sale_year,
    CASE e.focal_exposure_025
      WHEN 'treated_only' THEN 'treated'
      ELSE 'control'
    END AS exposure_group,
    count(*) AS sales,
    count(DISTINCT s.pin) AS parcels,
    round(avg(s.sale_price_real_2022), 2) AS mean_sale_price_real_2022,
    round(median(s.sale_price_real_2022), 2) AS median_sale_price_real_2022
  FROM home_sales s
  JOIN exposure e USING (row_id)
  WHERE e.focal_exposure_025 IN ('treated_only', 'control_only')
    AND e.n_welcoming_schools_025 = 0
    AND e.n_other_candidate_sites_025 = 0
  GROUP BY s.sale_year, e.focal_exposure_025
  ORDER BY s.sale_year, exposure_group
")
fwrite(
  annual_real_price_summary,
  "../output/annual_real_price_summary.csv"
)

hedonic_sales <- dbGetQuery(connection, "
  SELECT
    s.row_id,
    CAST(s.pin AS VARCHAR) AS pin,
    s.sale_year,
    s.sale_month,
    s.sale_price_real_2022,
    s.analysis_class,
    s.res_char_yrblt,
    s.res_char_bldg_sf,
    s.res_char_land_sf,
    s.res_char_beds,
    s.res_char_rooms,
    s.res_char_fbath,
    s.res_char_type_resd,
    s.res_char_cnst_qlty,
    s.res_char_repair_cnd,
    s.apartment_count,
    CASE e.focal_exposure_025
      WHEN 'treated_only' THEN e.nearest_treated_site_id
      ELSE e.nearest_control_site_id
    END AS school_site_id,
    CASE e.focal_exposure_025
      WHEN 'treated_only' THEN 'treated'
      ELSE 'control'
    END AS exposure_group
  FROM home_sales s
  JOIN exposure e USING (row_id)
  WHERE e.focal_exposure_025 IN ('treated_only', 'control_only')
    AND e.n_welcoming_schools_025 = 0
    AND e.n_other_candidate_sites_025 = 0
")
setDT(hedonic_sales)
hedonic_sales[, `:=`(
  log_real_price = log(sale_price_real_2022),
  log_building_sqft = log(res_char_bldg_sf),
  log_land_sqft = log(res_char_land_sf),
  age_at_sale = sale_year - res_char_yrblt,
  apartments = fcoalesce(apartment_count, 0)
)]

hedonic_columns <- c(
  "log_real_price", "log_building_sqft", "log_land_sqft", "age_at_sale",
  "res_char_beds", "res_char_rooms", "res_char_fbath", "apartments",
  "analysis_class", "res_char_type_resd", "res_char_cnst_qlty",
  "res_char_repair_cnd", "sale_month", "school_site_id"
)
if (any(!complete.cases(hedonic_sales[, ..hedonic_columns]))) {
  stop("The hedonic sample contains missing core characteristics.", call. = FALSE)
}
finite_hedonic_columns <- c(
  "log_real_price", "log_building_sqft", "log_land_sqft", "age_at_sale",
  "res_char_beds", "res_char_rooms", "res_char_fbath", "apartments",
  "analysis_class", "sale_month"
)
if (any(!is.finite(as.matrix(
  hedonic_sales[, ..finite_hedonic_columns]
)))) {
  stop("The hedonic sample contains a non-finite value.", call. = FALSE)
}

hedonic_model <- lm(
  log_real_price ~
    log_building_sqft + I(log_building_sqft^2) +
    log_land_sqft + I(log_land_sqft^2) +
    age_at_sale + I(age_at_sale^2) +
    res_char_beds + res_char_rooms + res_char_fbath + apartments +
    factor(analysis_class) + factor(res_char_type_resd) +
    factor(res_char_cnst_qlty) + factor(res_char_repair_cnd) +
    factor(sale_month) + factor(school_site_id),
  data = hedonic_sales
)

hedonic_sales[, residualized_sale_price_real_2022 := exp(
  mean(log_real_price) + residuals(hedonic_model)
)]
annual_residualized_real_price_summary <- hedonic_sales[, .(
  sales = .N,
  parcels = uniqueN(pin),
  mean_sale_price_real_2022 = round(mean(sale_price_real_2022), 2),
  median_sale_price_real_2022 = round(median(sale_price_real_2022), 2),
  mean_residualized_sale_price_real_2022 = round(
    mean(residualized_sale_price_real_2022),
    2
  ),
  median_residualized_sale_price_real_2022 = round(
    median(residualized_sale_price_real_2022),
    2
  )
), by = .(sale_year, exposure_group)]
setorder(
  annual_residualized_real_price_summary,
  sale_year,
  exposure_group
)
fwrite(
  annual_residualized_real_price_summary,
  "../output/annual_residualized_real_price_summary.csv"
)

hedonic_sales[, sale_half := fifelse(sale_month <= 6, 1L, 2L)]
hedonic_sales[, `:=`(
  half_year_index = sale_year + (sale_half - 0.5) / 2,
  quarter_index = sale_year + (ceiling(sale_month / 3) - 0.5) / 4
)]

semiannual_residualized_prices <- hedonic_sales[
  sale_year %between% c(2010, 2017),
  .(
    frequency = "semiannual",
    period = sprintf("%d H%d", sale_year[1], sale_half[1]),
    period_index = half_year_index[1],
    sales = .N,
    parcels = uniqueN(pin),
    mean_residualized_sale_price_real_2022 = round(
      mean(residualized_sale_price_real_2022),
      2
    ),
    median_residualized_sale_price_real_2022 = round(
      median(residualized_sale_price_real_2022),
      2
    )
  ),
  by = .(sale_year, sale_half, exposure_group)
]

quarterly_residualized_prices <- hedonic_sales[
  sale_year %between% c(2010, 2017),
  .(
    frequency = "quarterly",
    period = sprintf("%d Q%d", sale_year[1], ceiling(sale_month[1] / 3)),
    period_index = quarter_index[1],
    sales = .N,
    parcels = uniqueN(pin),
    mean_residualized_sale_price_real_2022 = round(
      mean(residualized_sale_price_real_2022),
      2
    ),
    median_residualized_sale_price_real_2022 = round(
      median(residualized_sale_price_real_2022),
      2
    )
  ),
  by = .(
    sale_year,
    sale_quarter = ceiling(sale_month / 3),
    exposure_group
  )
]

subannual_residualized_real_price_summary <- rbindlist(
  list(
    semiannual_residualized_prices[, sale_quarter := NA_integer_],
    quarterly_residualized_prices[, sale_half := NA_integer_]
  ),
  use.names = TRUE,
  fill = TRUE
)
setcolorder(
  subannual_residualized_real_price_summary,
  c(
    "frequency", "period", "period_index", "sale_year", "sale_half",
    "sale_quarter", "exposure_group", "sales", "parcels",
    "mean_residualized_sale_price_real_2022",
    "median_residualized_sale_price_real_2022"
  )
)
setorder(
  subannual_residualized_real_price_summary,
  frequency,
  period_index,
  exposure_group
)
fwrite(
  subannual_residualized_real_price_summary,
  "../output/subannual_residualized_real_price_summary.csv"
)

school_site_support <- dbGetQuery(connection, "
  WITH focal_sites AS (
    SELECT
      school_site_id AS school_location_id,
      string_agg(
        school_name_sy1213,
        ' / '
        ORDER BY school_name_sy1213
      ) AS school_names,
      max(housing_treat_30) AS housing_treat_30,
      max(housing_control_49) AS housing_control_49,
      max(latitude_sy1213) AS latitude,
      max(longitude_sy1213) AS longitude
    FROM schools
    GROUP BY school_site_id
    HAVING max(housing_treat_30) = 1 OR max(housing_control_49) = 1
  ),
  ring_support AS (
    SELECT
      d.school_location_id,
      count(*) AS sales_in_ring,
      count(DISTINCT s.pin) AS parcels_in_ring,
      count(*) FILTER (WHERE s.sale_year <= 2012) AS sales_2008_2012,
      count(*) FILTER (WHERE s.sale_year = 2013) AS sales_2013,
      count(*) FILTER (WHERE s.sale_year >= 2014) AS sales_2014_2018,
      count(*) FILTER (
        WHERE e.focal_exposure_025 = 'treated_control_overlap'
      ) AS treated_control_overlap_sales,
      count(*) FILTER (
        WHERE e.n_welcoming_schools_025 > 0
      ) AS welcoming_exposure_sales,
      count(*) FILTER (
        WHERE e.n_other_candidate_sites_025 > 0
      ) AS other_candidate_exposure_sales
    FROM distances d
    JOIN home_sales s USING (row_id)
    JOIN exposure e USING (row_id)
    WHERE d.school_location_role = 'candidate_site'
      AND (d.housing_treat_30 = 1 OR d.housing_control_49 = 1)
      AND d.distance_feet <= 1320
    GROUP BY d.school_location_id
  ),
  nearest_support AS (
    SELECT
      CASE e.focal_exposure_025
        WHEN 'treated_only' THEN e.nearest_treated_site_id
        WHEN 'control_only' THEN e.nearest_control_site_id
      END AS school_location_id,
      count(*) AS nearest_unambiguous_sales,
      count(*) FILTER (
        WHERE e.n_welcoming_schools_025 = 0
          AND e.n_other_candidate_sites_025 = 0
      ) AS nearest_uncontaminated_sales
    FROM home_sales s
    JOIN exposure e USING (row_id)
    WHERE e.focal_exposure_025 IN ('treated_only', 'control_only')
    GROUP BY school_location_id
  )
  SELECT
    f.school_location_id,
    f.school_names,
    CASE WHEN f.housing_treat_30 = 1 THEN 'treated' ELSE 'control' END
      AS exposure_group,
    f.latitude,
    f.longitude,
    coalesce(r.sales_in_ring, 0) AS sales_in_ring,
    coalesce(r.parcels_in_ring, 0) AS parcels_in_ring,
    coalesce(r.sales_2008_2012, 0) AS sales_2008_2012,
    coalesce(r.sales_2013, 0) AS sales_2013,
    coalesce(r.sales_2014_2018, 0) AS sales_2014_2018,
    coalesce(r.treated_control_overlap_sales, 0)
      AS treated_control_overlap_sales,
    coalesce(r.welcoming_exposure_sales, 0) AS welcoming_exposure_sales,
    coalesce(r.other_candidate_exposure_sales, 0)
      AS other_candidate_exposure_sales,
    coalesce(n.nearest_unambiguous_sales, 0) AS nearest_unambiguous_sales,
    coalesce(n.nearest_uncontaminated_sales, 0)
      AS nearest_uncontaminated_sales
  FROM focal_sites f
  LEFT JOIN ring_support r USING (school_location_id)
  LEFT JOIN nearest_support n USING (school_location_id)
  ORDER BY exposure_group, school_names
")
fwrite(school_site_support, "../output/school_site_support.csv")

treated_control_overlap_pairs <- dbGetQuery(connection, "
  WITH focal_sites AS (
    SELECT
      school_site_id AS school_location_id,
      string_agg(
        school_name_sy1213,
        ' / '
        ORDER BY school_name_sy1213
      ) AS school_names,
      max(x_coordinate_sy1213) AS x,
      max(y_coordinate_sy1213) AS y
    FROM schools
    GROUP BY school_site_id
  )
  SELECT
    e.nearest_treated_site_id,
    t.school_names AS treated_school_names,
    e.nearest_control_site_id,
    c.school_names AS control_school_names,
    round(sqrt(pow(t.x - c.x, 2) + pow(t.y - c.y, 2)), 1)
      AS school_distance_feet,
    count(*) AS sales,
    count(DISTINCT s.pin) AS parcels,
    count(*) FILTER (WHERE s.sale_year <= 2012) AS sales_2008_2012,
    count(*) FILTER (WHERE s.sale_year = 2013) AS sales_2013,
    count(*) FILTER (WHERE s.sale_year >= 2014) AS sales_2014_2018
  FROM home_sales s
  JOIN exposure e USING (row_id)
  JOIN focal_sites t ON e.nearest_treated_site_id = t.school_location_id
  JOIN focal_sites c ON e.nearest_control_site_id = c.school_location_id
  WHERE e.focal_exposure_025 = 'treated_control_overlap'
  GROUP BY
    e.nearest_treated_site_id,
    t.school_names,
    t.x,
    t.y,
    e.nearest_control_site_id,
    c.school_names,
    c.x,
    c.y
  ORDER BY sales DESC, nearest_treated_site_id, nearest_control_site_id
")
fwrite(
  treated_control_overlap_pairs,
  "../output/treated_control_overlap_pairs.csv"
)

competing_exposure <- dbGetQuery(connection, "
  SELECT
    e.focal_exposure_025,
    CASE
      WHEN e.n_welcoming_schools_025 > 0
        AND e.n_other_candidate_sites_025 > 0
        THEN 'welcoming_and_other_candidate'
      WHEN e.n_welcoming_schools_025 > 0 THEN 'welcoming_only'
      WHEN e.n_other_candidate_sites_025 > 0 THEN 'other_candidate_only'
      ELSE 'none'
    END AS competing_exposure,
    count(*) AS sales,
    count(DISTINCT s.pin) AS parcels,
    round(
      100 * count(*) /
        sum(count(*)) OVER (PARTITION BY e.focal_exposure_025),
      2
    ) AS category_percent
  FROM home_sales s
  JOIN exposure e USING (row_id)
  GROUP BY e.focal_exposure_025, competing_exposure
  ORDER BY e.focal_exposure_025, sales DESC
")
fwrite(competing_exposure, "../output/competing_exposure.csv")

radius_sensitivity <- dbGetQuery(connection, "
  WITH radii(radius_miles, radius_feet) AS (
    VALUES (0.125, 660), (0.25, 1320), (0.50, 2640)
  )
  SELECT
    radius_miles,
    radius_feet,
    count(*) FILTER (
      WHERE e.nearest_treated_site_distance_feet <= radius_feet
        AND e.nearest_control_site_distance_feet > radius_feet
    ) AS treated_only_sales,
    count(*) FILTER (
      WHERE e.nearest_treated_site_distance_feet > radius_feet
        AND e.nearest_control_site_distance_feet <= radius_feet
    ) AS control_only_sales,
    count(*) FILTER (
      WHERE e.nearest_treated_site_distance_feet <= radius_feet
        AND e.nearest_control_site_distance_feet <= radius_feet
    ) AS treated_control_overlap_sales,
    count(*) FILTER (
      WHERE e.nearest_treated_site_distance_feet > radius_feet
        AND e.nearest_control_site_distance_feet > radius_feet
    ) AS outside_focal_rings_sales,
    round(
      100 * count(*) FILTER (
        WHERE e.nearest_treated_site_distance_feet <= radius_feet
          AND e.nearest_control_site_distance_feet <= radius_feet
      ) /
        count(*) FILTER (
          WHERE e.nearest_treated_site_distance_feet <= radius_feet
            OR e.nearest_control_site_distance_feet <= radius_feet
        ),
      2
    ) AS overlap_among_focal_exposed_percent
  FROM home_sales s
  JOIN exposure e USING (row_id)
  CROSS JOIN radii
  WHERE e.has_school_distances
  GROUP BY radius_miles, radius_feet
  ORDER BY radius_miles
")
fwrite(radius_sensitivity, "../output/radius_sensitivity.csv")

map_sales <- dbGetQuery(connection, "
  SELECT
    g.centroid_x_crs_3435 AS x,
    g.centroid_y_crs_3435 AS y,
    e.focal_exposure_025
  FROM home_sales s
  JOIN geocoded_sales g USING (row_id)
  JOIN exposure e USING (row_id)
  WHERE e.has_school_distances
")

map_schools <- dbGetQuery(connection, "
  SELECT
    school_site_id,
    max(x_coordinate_sy1213) AS x,
    max(y_coordinate_sy1213) AS y,
    max(housing_treat_30) AS housing_treat_30,
    max(housing_control_49) AS housing_control_49
  FROM schools
  GROUP BY school_site_id
  HAVING max(housing_treat_30) = 1 OR max(housing_control_49) = 1
")

stopifnot(
  nrow(map_sales) == 167467,
  nrow(map_schools) == 78,
  nrow(exposure_summary) == 5,
  nrow(treatment_control_summary) == 8,
  nrow(annual_real_price_summary) == 22,
  nrow(annual_residualized_real_price_summary) == 22,
  nrow(subannual_residualized_real_price_summary) == 96,
  nobs(hedonic_model) == 10921,
  all(annual_real_price_summary$sale_year %in% 2008:2018),
  all(
    annual_residualized_real_price_summary$sale_year %in% 2008:2018
  ),
  sum(
    annual_real_price_summary$sales[
      annual_real_price_summary$exposure_group == "treated"
    ]
  ) == 3287,
  sum(
    annual_real_price_summary$sales[
      annual_real_price_summary$exposure_group == "control"
    ]
  ) == 7634,
  nrow(school_site_support) == 78,
  sum(treated_control_overlap_pairs$sales) == 337,
  nrow(radius_sensitivity) == 3,
  school_site_support$sales_in_ring[
    school_site_support$school_location_id == 609845
  ] == 0
)

setDT(annual_real_price_summary)
control_prices <- annual_real_price_summary[exposure_group == "control"]
treated_prices <- annual_real_price_summary[exposure_group == "treated"]
stopifnot(identical(control_prices$sale_year, treated_prices$sale_year))

png(
  "../output/real_price_trends.png",
  width = 1800,
  height = 1050,
  res = 220
)
par(
  mfrow = c(1, 2),
  mar = c(4.2, 6.6, 3.5, 1),
  oma = c(1.5, 0, 2.5, 0)
)

price_columns <- c(
  "mean_sale_price_real_2022",
  "median_sale_price_real_2022"
)
panel_titles <- c("Annual mean", "Annual median")

for (panel in seq_along(price_columns)) {
  price_column <- price_columns[panel]
  price_range <- range(
    control_prices[[price_column]],
    treated_prices[[price_column]]
  )
  price_ticks <- pretty(price_range)

  plot(
    control_prices$sale_year,
    control_prices[[price_column]],
    type = "o",
    pch = 16,
    lwd = 2,
    col = "#2166AC",
    ylim = range(price_ticks),
    axes = FALSE,
    xlab = "Sale year",
    ylab = "Real sale price (2022 dollars)",
    main = panel_titles[panel]
  )
  lines(
    treated_prices$sale_year,
    treated_prices[[price_column]],
    type = "o",
    pch = 17,
    lwd = 2,
    col = "#D73027"
  )
  axis(1, at = 2008:2018, labels = 2008:2018, las = 2, cex.axis = 0.75)
  axis(
    2,
    at = price_ticks,
    labels = paste0(
      "$",
      format(
        round(price_ticks / 1000),
        trim = TRUE,
        big.mark = ",",
        scientific = FALSE
      ),
      "k"
    ),
    las = 1,
    cex.axis = 0.8
  )
  box()
  abline(v = 2013, lty = 3, col = "grey35")
  legend(
    "topleft",
    legend = c("Treated", "Control"),
    col = c("#D73027", "#2166AC"),
    pch = c(17, 16),
    lwd = 2,
    bty = "n"
  )
}

mtext(
  "Quarter-mile homes with no welcoming or other candidate school exposure",
  side = 3,
  outer = TRUE,
  line = 0.8,
  font = 2,
  cex = 1.1
)
mtext(
  "Dashed line marks the 2013 closure year",
  side = 1,
  outer = TRUE,
  line = 0.3,
  cex = 0.75
)
dev.off()

control_residualized_prices <- annual_residualized_real_price_summary[
  exposure_group == "control"
]
treated_residualized_prices <- annual_residualized_real_price_summary[
  exposure_group == "treated"
]

png(
  "../output/residualized_real_price_trends.png",
  width = 1800,
  height = 1050,
  res = 220
)
par(
  mfrow = c(1, 2),
  mar = c(4.2, 6.6, 3.5, 1),
  oma = c(2.5, 0, 5, 0)
)

residualized_price_columns <- c(
  "mean_residualized_sale_price_real_2022",
  "median_residualized_sale_price_real_2022"
)
residualized_panel_titles <- c("Annual mean", "Annual median")

for (panel in seq_along(residualized_price_columns)) {
  price_column <- residualized_price_columns[panel]
  price_range <- range(
    control_residualized_prices[[price_column]],
    treated_residualized_prices[[price_column]]
  )
  price_ticks <- pretty(price_range)

  plot(
    control_residualized_prices$sale_year,
    control_residualized_prices[[price_column]],
    type = "o",
    pch = 16,
    lwd = 2,
    col = "#2166AC",
    ylim = range(price_ticks),
    axes = FALSE,
    xlab = "Sale year",
    ylab = "Residualized price (2022-dollar scale)",
    main = residualized_panel_titles[panel]
  )
  lines(
    treated_residualized_prices$sale_year,
    treated_residualized_prices[[price_column]],
    type = "o",
    pch = 17,
    lwd = 2,
    col = "#D73027"
  )
  axis(1, at = 2008:2018, labels = 2008:2018, las = 2, cex.axis = 0.75)
  axis(
    2,
    at = price_ticks,
    labels = paste0(
      "$",
      format(
        round(price_ticks / 1000),
        trim = TRUE,
        big.mark = ",",
        scientific = FALSE
      ),
      "k"
    ),
    las = 1,
    cex.axis = 0.8
  )
  box()
  abline(v = 2013, lty = 3, col = "grey35")
  legend(
    "topleft",
    legend = c("Treated", "Control"),
    col = c("#D73027", "#2166AC"),
    pch = c(17, 16),
    lwd = 2,
    bty = "n"
  )
}

mtext(
  "Prices adjusted for property characteristics and school-site fixed effects",
  side = 3,
  outer = TRUE,
  line = 2.5,
  font = 2,
  cex = 1.1
)
mtext(
  "Quarter-mile homes with no welcoming or other candidate exposure",
  side = 3,
  outer = TRUE,
  line = 1,
  cex = 0.8
)
mtext(
  "Dashed line marks the 2013 closure year",
  side = 1,
  outer = TRUE,
  line = 0.8,
  cex = 0.75
)
dev.off()

panel_frequencies <- c(
  "semiannual",
  "semiannual",
  "quarterly",
  "quarterly"
)
panel_price_columns <- c(
  "mean_residualized_sale_price_real_2022",
  "median_residualized_sale_price_real_2022",
  "mean_residualized_sale_price_real_2022",
  "median_residualized_sale_price_real_2022"
)
panel_titles <- c(
  "Semiannual mean",
  "Semiannual median",
  "Quarterly mean",
  "Quarterly median"
)

png(
  "../output/subannual_residualized_real_price_trends.png",
  width = 1800,
  height = 1700,
  res = 220
)
par(
  mfrow = c(2, 2),
  mar = c(4.2, 6.2, 3.5, 1),
  oma = c(3.4, 0, 4.5, 0)
)

for (panel in seq_along(panel_titles)) {
  panel_data <- subannual_residualized_real_price_summary[
    frequency == panel_frequencies[panel]
  ]
  control_panel <- panel_data[exposure_group == "control"]
  treated_panel <- panel_data[exposure_group == "treated"]
  price_column <- panel_price_columns[panel]
  price_ticks <- pretty(range(panel_data[[price_column]]))

  plot(
    control_panel$period_index,
    control_panel[[price_column]],
    type = "o",
    pch = 16,
    lwd = 1.7,
    cex = 0.7,
    col = "#2166AC",
    xlim = c(2010, 2018),
    ylim = range(price_ticks),
    axes = FALSE,
    xlab = "Sale period",
    ylab = "Residualized price (2022-dollar scale)",
    main = panel_titles[panel]
  )
  lines(
    treated_panel$period_index,
    treated_panel[[price_column]],
    type = "o",
    pch = 17,
    lwd = 1.7,
    cex = 0.7,
    col = "#D73027"
  )
  axis(
    1,
    at = 2010:2018,
    labels = 2010:2018,
    las = 2,
    cex.axis = 0.72
  )
  axis(
    2,
    at = price_ticks,
    labels = paste0(
      "$",
      format(
        round(price_ticks / 1000),
        trim = TRUE,
        big.mark = ",",
        scientific = FALSE
      ),
      "k"
    ),
    las = 1,
    cex.axis = 0.72
  )
  box()
  abline(v = 2013 + 43 / 365, lty = 3, col = "grey35")
  abline(v = 2013 + 79 / 365, lty = 2, col = "grey35")
  legend(
    "topleft",
    legend = c("Treated", "Control"),
    col = c("#D73027", "#2166AC"),
    pch = c(17, 16),
    lwd = 1.7,
    bty = "n",
    cex = 0.8
  )
}

mtext(
  "Higher-frequency residualized real sale prices",
  side = 3,
  outer = TRUE,
  line = 2.3,
  font = 2,
  cex = 1.1
)
mtext(
  "Property characteristics and nearest-school-site fixed effects",
  side = 3,
  outer = TRUE,
  line = 0.8,
  cex = 0.82
)
mtext(
  paste0(
    "Dotted: February 13 candidate list; dashed: March 21 closure proposals. ",
    "Periods use recorded sale dates."
  ),
  side = 1,
  outer = TRUE,
  line = 1.2,
  cex = 0.72
)
dev.off()

png(
  "../output/home_school_exposure_map.png",
  width = 1800,
  height = 2100,
  res = 220
)
par(mar = c(1, 1, 3.5, 1), xaxs = "i", yaxs = "i")
plot(
  map_sales$x,
  map_sales$y,
  type = "n",
  asp = 1,
  axes = FALSE,
  xlab = "",
  ylab = "",
  main = "Quarter-mile school rings and clean home sales",
  sub = "Closed candidate sites in red; listed sites that stayed open in blue"
)
points(
  map_sales$x,
  map_sales$y,
  pch = 16,
  cex = 0.12,
  col = adjustcolor("grey55", alpha.f = 0.20)
)

control_sites <- map_schools[map_schools$housing_control_49 == 1, ]
treated_sites <- map_schools[map_schools$housing_treat_30 == 1, ]
symbols(
  control_sites$x,
  control_sites$y,
  circles = rep(1320, nrow(control_sites)),
  inches = FALSE,
  add = TRUE,
  fg = adjustcolor("#2166AC", alpha.f = 0.70),
  lwd = 1.1
)
symbols(
  treated_sites$x,
  treated_sites$y,
  circles = rep(1320, nrow(treated_sites)),
  inches = FALSE,
  add = TRUE,
  fg = adjustcolor("#D73027", alpha.f = 0.70),
  lwd = 1.1
)

points(
  map_sales$x[map_sales$focal_exposure_025 == "control_only"],
  map_sales$y[map_sales$focal_exposure_025 == "control_only"],
  pch = 16,
  cex = 0.22,
  col = adjustcolor("#2166AC", alpha.f = 0.65)
)
points(
  map_sales$x[map_sales$focal_exposure_025 == "treated_only"],
  map_sales$y[map_sales$focal_exposure_025 == "treated_only"],
  pch = 16,
  cex = 0.22,
  col = adjustcolor("#D73027", alpha.f = 0.65)
)
points(
  map_sales$x[
    map_sales$focal_exposure_025 == "treated_control_overlap"
  ],
  map_sales$y[
    map_sales$focal_exposure_025 == "treated_control_overlap"
  ],
  pch = 16,
  cex = 0.32,
  col = adjustcolor("#7B3294", alpha.f = 0.80)
)
points(
  control_sites$x,
  control_sites$y,
  pch = 21,
  cex = 0.75,
  bg = "white",
  col = "#2166AC",
  lwd = 1.2
)
points(
  treated_sites$x,
  treated_sites$y,
  pch = 24,
  cex = 0.82,
  bg = "white",
  col = "#D73027",
  lwd = 1.2
)

carver <- map_schools[map_schools$school_site_id == 609845, ]
text(
  carver$x,
  carver$y,
  labels = "Carver Primary",
  pos = 2,
  offset = 0.5,
  cex = 0.65
)
legend(
  "bottomleft",
  legend = c(
    "Closed site and ring",
    "Stayed-open site and ring",
    "Sale inside both rings"
  ),
  pch = c(24, 21, 16),
  pt.bg = c("white", "white", "#7B3294"),
  col = c("#D73027", "#2166AC", "#7B3294"),
  pt.cex = c(0.9, 0.9, 0.65),
  bty = "n",
  cex = 0.72
)
dev.off()

dbDisconnect(connection, shutdown = TRUE)

cat(sprintf(
  paste0(
    "Audited %s clean sales around 29 treated and 49 control sites; ",
    "the hedonic model used %s sales (R-squared %.3f) and wrote thirteen outputs.\n"
  ),
  format(integrity$sales, big.mark = ","),
  format(nobs(hedonic_model), big.mark = ","),
  summary(hedonic_model)$r.squared
))
