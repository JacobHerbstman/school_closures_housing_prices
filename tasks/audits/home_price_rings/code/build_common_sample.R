# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_rings/code")
suppressPackageStartupMessages({library(data.table); library(arrow); library(digest)})
# The existing half-mile assignments already exclude every second focal,
# welcoming, and other candidate site within 2,640 feet.
assignments <- as.data.table(read_parquet("../output/ring_assignments.parquet"))[ring == "within_05"]
sales <- fread("../input/home_sales_2008_2018.csv", select = c("row_id", "sale_year"), colClasses = c(row_id = "character"))
stopifnot(!anyDuplicated(assignments$row_id), !anyDuplicated(sales$row_id),
          all(assignments$row_id %in% sales$row_id), all(assignments$distance_feet <= 2640))
# One isolated half-mile transaction matches exactly one cleaned sale.
assignments <- merge(assignments, sales, by = "row_id", all.x = TRUE)
assignments[, ring := fifelse(distance_feet <= 660, "within_0125",
                     fifelse(distance_feet <= 1320, "annulus_0125_025", "annulus_025_05"))]
rings <- c("within_0125", "annulus_0125_025", "annulus_025_05")
status <- unique(assignments[, .(school_site_id, treated)])
stopifnot(!anyDuplicated(status$school_site_id))
# Unique site-band-year counts join a complete grid, making empty cells explicit.
counts <- assignments[, .(sales = .N), by = .(school_site_id, ring, sale_year)]
support <- merge(CJ(school_site_id = status$school_site_id, ring = rings, sale_year = 2008:2018), status, by = "school_site_id")
support <- merge(support, counts, by = c("school_site_id", "ring", "sale_year"), all.x = TRUE)
support[is.na(sales), sales := 0L]
support[, common_year := all(sales > 0), by = .(school_site_id, sale_year)]
support[, common_site := any(common_year & sale_year <= 2012) & any(common_year & sale_year >= 2014), by = school_site_id]
support[, included := common_year & common_site]
# Every retained site-year has all three bands; roster selection uses sales
# availability, including post-treatment years, not prices or estimates.
eligible <- support[included == TRUE, .(school_site_id, ring, sale_year)]
stopifnot(!anyDuplicated(eligible), all(eligible[, .N, by = .(school_site_id, sale_year)]$N == 3L))
selected <- merge(assignments, eligible, by = c("school_site_id", "ring", "sale_year"))
stopifnot(nrow(selected) == support[included == TRUE, sum(sales)], !anyDuplicated(selected$row_id))
summaries <- assignments[, .(sales_halfmile_exclusion = .N, sites_halfmile_exclusion = uniqueN(school_site_id)), by = .(ring, treated)]
roster_counts <- assignments[school_site_id %in% support[common_site == TRUE, unique(school_site_id)],
  .(sales_common_roster = .N), by = .(ring, treated)]
final_counts <- selected[, .(sales = .N, sites = uniqueN(school_site_id), pre_sales = sum(sale_year <= 2012),
  transition_sales = sum(sale_year == 2013), post_sales = sum(sale_year >= 2014), site_years = uniqueN(paste(school_site_id, sale_year))), by = .(ring, treated)]
summaries <- merge(merge(summaries, roster_counts, by = c("ring", "treated")), final_counts, by = c("ring", "treated"))
stopifnot(nrow(summaries) == 6L, all(summaries$sales <= summaries$sales_common_roster),
          all(summaries$sales_common_roster <= summaries$sales_halfmile_exclusion))
# Each buffer combines the same site's eligible annuli in the same years.
selected <- rbindlist(list(selected, copy(selected[distance_feet <= 1320])[, ring := "within_025"],
                         copy(selected)[, ring := "within_05"]))
selected <- selected[, .(ring, row_id, school_site_id, treated, distance_feet)]
setorder(selected, ring, row_id)
stopifnot(!anyDuplicated(selected[, .(ring, row_id)]), !anyNA(selected))
write_parquet(selected, "../output/common_ring_assignments.parquet")
fwrite(support, "../output/common_support.csv")
fwrite(summaries, "../output/common_sample_summary.csv")
saved <- as.data.table(read_parquet("../output/common_ring_assignments.parquet"))
saved_support <- fread("../output/common_support.csv")
stopifnot(identical(saved, selected), isTRUE(all.equal(as.data.frame(saved_support), as.data.frame(support), check.attributes = FALSE)),
          !anyDuplicated(saved_support[, .(school_site_id, ring, sale_year)]))
schema <- data.table(column = names(saved), type = vapply(saved, function(x) paste(class(x), collapse = "/"), character(1)),
  nonmissing = vapply(saved, function(x) sum(!is.na(x)), integer(1)), distinct = vapply(saved, uniqueN, integer(1)))
report <- c("Common ring assignments: first verified baseline", "Key: ring, row_id.",
  "Fixed 2,640-foot exclusion of other sites; identical included site-years across bands.",
  "Sites need at least one common year before 2013 and one after; annual roster may change.",
  paste("Assignment rows:", nrow(saved)), capture.output(print(schema)), capture.output(summary(saved)),
  "Support key: school_site_id, ring, sale_year. Empty cells explicitly recorded.",
  paste("Support rows:", nrow(saved_support)), capture.output(str(saved_support)), capture.output(summary(saved_support)),
  capture.output(print(summaries)),
  paste("Assignments SHA256:", digest("../output/common_ring_assignments.parquet", file = TRUE, algo = "sha256")),
  paste("Support SHA256:", digest("../output/common_support.csv", file = TRUE, algo = "sha256")))
writeLines(trimws(report, which = "right"), "../report/common_ring_assignments.txt")
print(summaries)
