# Shared data-report body. Callers read saved datasets and own their report files.
report_data <- function(data, label, key) {
  data <- data.table::as.data.table(data)
  stopifnot(all(key %in% names(data)), !anyNA(data[, ..key]),
            !anyDuplicated(data[, ..key]))
  cat("\nDataset:", label, "\nRows:", nrow(data), " Columns:", ncol(data),
      "\nKey:", paste(key, collapse=", "), "\nDuplicate or missing keys: 0\n")
  for (column in names(data)) {
    values <- data[[column]]
    cat(column, "|", paste(class(values), collapse="/"),
        "| nonmissing:", sum(!is.na(values)),
        "| distinct nonmissing:", data.table::uniqueN(values[!is.na(values)]), "\n")
    if (is.numeric(values)) print(summary(values))
    else print(head(sort(unique(values[!is.na(values)])), 6))
  }
  cat("First six records:\n")
  print(head(data))
}
