# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/tract_demographic_change/code")
suppressPackageStartupMessages(library(data.table))

# Cook County tract counts from the 2000 Census (SF3; incomes are 1999 dollars)
# and the 2008-2012 ACS five-year estimates (2012 dollars). Both are fixed
# releases. The key is read from the ignored project .Renviron and never logged.
readRenviron("../../../../.Renviron")
key <- Sys.getenv("CENSUS_API_KEY")
stopifnot(nzchar(key))
query <- function(dataset, variables) {
  url <- sprintf("https://api.census.gov/data/%s?get=%s&for=tract:*&in=state:17%%20county:031&key=%s",
                 dataset, paste(variables, collapse = ","), key)
  response <- jsonlite::fromJSON(url)
  data <- as.data.table(response[-1, , drop = FALSE])
  setnames(data, response[1, ])
  data
}

# Adults 25+ and those with a bachelor's degree or more (male and female
# categories), non-Hispanic white and Black residents, aggregate household
# income, and households.
sf3_names <- c(adults_25 = "P037001", male_ba = "P037015", male_ma = "P037016", male_prof = "P037017", male_phd = "P037018",
               female_ba = "P037032", female_ma = "P037033", female_prof = "P037034", female_phd = "P037035",
               population = "P007001", nh_white = "P007003", nh_black = "P007004",
               aggregate_household_income = "P054001", households = "P052001")
acs_names <- c(adults_25 = "B15002_001E", male_ba = "B15002_015E", male_ma = "B15002_016E", male_prof = "B15002_017E",
               male_phd = "B15002_018E", female_ba = "B15002_032E", female_ma = "B15002_033E", female_prof = "B15002_034E",
               female_phd = "B15002_035E", population = "B03002_001E", nh_white = "B03002_003E", nh_black = "B03002_004E",
               aggregate_household_income = "B19025_001E", households = "B19001_001E")
sf3 <- query("2000/dec/sf3", sf3_names)
acs <- query("2012/acs/acs5", acs_names)
setnames(sf3, sf3_names, names(sf3_names))
setnames(acs, acs_names, names(acs_names))
# 2000 API tract codes omit a zero suffix ("0101" is tract 010100).
sf3[, tract := fifelse(nchar(tract) == 4L, paste0(tract, "00"), tract)]
counts <- rbind(
  melt(sf3[tract != "000000"], id.vars = c("state", "county", "tract"), variable.name = "measure")[, vintage := "2000"],
  melt(acs, id.vars = c("state", "county", "tract"), variable.name = "measure")[, vintage := "2008-2012"])
counts[, `:=`(geoid = paste0(state, county, tract), value = as.numeric(value))]
counts <- counts[, .(vintage, geoid, measure, value)]
stopifnot(!anyDuplicated(counts[, .(vintage, geoid, measure)]), all(nchar(counts$geoid) == 11L),
          counts[vintage == "2000", uniqueN(geoid)] > 1000L, counts[vintage == "2008-2012", uniqueN(geoid)] > 1000L)
setorder(counts, vintage, geoid, measure)
fwrite(counts, "../temp/census_tract_counts.csv")
stopifnot(file.rename("../temp/census_tract_counts.csv", "../output/census_tract_counts.csv"))
