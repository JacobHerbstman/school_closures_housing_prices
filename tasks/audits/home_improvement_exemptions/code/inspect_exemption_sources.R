suppressPackageStartupMessages(library(data.table))
source("load_ccao_reference.R")

exemptions <- as.data.table(arrow::read_parquet("../input/hie_data.parquet"))
transactions <- fread(
  "../input/home_sales_with_characteristics_2006_2025.csv",
  select = c("row_id", "pin", "sale_year", "single_improvement_card"),
  colClasses = list(character = c("row_id", "pin"))
)
model_source <- jsonlite::fromJSON("../input/model_ingest.json")
metadata <- jsonlite::fromJSON("../input/improvement_metadata.json")

stopifnot(
  nrow(exemptions) == 134096L,
  uniqueN(exemptions$pin) == 121177L,
  !anyDuplicated(exemptions),
  all(grepl("^[0-9]{14}$", exemptions$pin)),
  !anyNA(exemptions$pin),
  all(exemptions$qu_home_improvement == "1"),
  identical(sort(unique(as.integer(exemptions$year))), 2000:2020),
  !anyDuplicated(transactions$row_id),
  identical(sort(unique(transactions$sale_year)), 2006:2025),
  model_source$encoding == "base64",
  model_source$path == "pipeline/00-ingest.R",
  metadata$id == "x54s-btds"
)

source_files <- c(
  "../input/hie_data.parquet", "../input/ccao.zip", "../input/model_ingest.json",
  "../input/improvement_metadata.json", "../input/home_sales_with_characteristics_2006_2025.csv"
)
inventory <- data.table(
  file = basename(source_files),
  bytes = file.info(source_files)$size,
  sha256 = vapply(source_files, digest::digest, character(1), algo = "sha256", file = TRUE)
)
expected <- fread("source_sha256.csv")
stopifnot(identical(inventory$sha256[match(expected$file, inventory$file)], expected$sha256))
fwrite(inventory, "../output/source_inventory.csv")
cat(sprintf("Pinned sources verified: %s exemptions; %s master transactions.\n", nrow(exemptions), nrow(transactions)))
print(exemptions[, .(exemptions = .N, parcels = uniqueN(pin)), by = year][order(year)])
