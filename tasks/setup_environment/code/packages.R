# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/setup_environment/code")

required_packages <- c(
  "DBI",
  "data.table",
  "duckdb",
  "fixest",
  "sf",
  "curl",
  "jsonlite",
  "arrow",
  "digest",
  "dplyr",
  "janitor",
  "readr",
  "tidyr",
  "ggplot2",
  "patchwork",
  "scales"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    sprintf("Required R packages are unavailable: %s", paste(missing_packages, collapse = ", ")),
    call. = FALSE
  )
}

package_versions <- data.frame(
  package = required_packages,
  version = vapply(required_packages, function(package) {
    as.character(utils::packageVersion(package))
  }, character(1))
)

output_file <- "../output/R_packages.txt"
write.table(package_versions, output_file, sep = "\t", row.names = FALSE, quote = FALSE)
cat(sprintf("Wrote R package versions to %s.\n", output_file))
