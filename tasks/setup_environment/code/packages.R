required_packages <- c("data.table", "curl", "jsonlite", "arrow", "digest")
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
temporary_output <- paste0(output_file, ".tmp")
write.table(package_versions, temporary_output, sep = "\t", row.names = FALSE, quote = FALSE)
if (!file.rename(temporary_output, output_file)) {
  stop("Could not move the R package record into place.", call. = FALSE)
}
cat(sprintf("Wrote R package versions to %s.\n", output_file))
