suppressPackageStartupMessages(library(data.table))

cpi <- fread(
  "https://fred.stlouisfed.org/graph/fredgraph.csv?id=CUURA207SA0",
  na.strings = c(".", "NA")
)

if (!all(c("observation_date", "CUURA207SA0") %in% names(cpi))) {
  stop("FRED response is missing the Chicago CPI columns.", call. = FALSE)
}

cpi <- cpi[, .(
  observation_date = as.IDate(observation_date),
  chicago_cpi_all_items = as.numeric(CUURA207SA0)
)]
setorder(cpi, observation_date)

required_months <- seq(
  as.IDate("2008-01-01"),
  as.IDate("2022-12-01"),
  by = "month"
)
required_cpi <- cpi[observation_date %between% range(required_months)]

stopifnot(
  nrow(cpi) > 0L,
  !anyDuplicated(cpi$observation_date),
  identical(required_cpi$observation_date, required_months),
  all(is.finite(required_cpi$chicago_cpi_all_items)),
  all(required_cpi$chicago_cpi_all_items > 0)
)

fwrite(
  cpi,
  "../output/chicago_cpi_all_items.csv",
  na = "NA"
)
