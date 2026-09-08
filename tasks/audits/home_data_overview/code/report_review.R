# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
library(data.table)
source("../../../shared/code/report_data.R")
audit <- readRDS("../output/data_review.rds")
report <- capture.output({
  cat("Saved RDS SHA-256:",digest::digest("../output/data_review.rds",file=TRUE,algo="sha256"),"\n")
  keys <- list(checks="check",schools="school_id",welcoming=c("closed_school_id","school_id"),sites="school_site_id",
   near_sites=c("site1","site2"),attrition=c("group","step"),annual_counts=c("stage","group","sale_year"),
   complete_prices=c("group","sale_year"),sample_changes=c("group","sale_year"),regression_attrition=c("group","step"),
   annual_prices=c("group","sale_year"),composition=c("group","sale_year","property_type"),support="school_site_id",
   site_year=c("school_site_id","sale_year"),geography=c("focal_exposure_025","n_welcoming_schools_025","n_other_candidate_sites_025"),
   selection=c("group","sale_year"),cutoffs="sale_year",location_variants=c("group","sale_year","variant"),map_sales="row_id",
   date_precision=c("group","sale_date_precision"),source_hashes="source")
  # Missing-coordinate exposure counts have undefined nearby-school counts.
  for(name in names(keys)) {
   d <- copy(audit[[name]])
   if(name=="geography") for(field in c("n_welcoming_schools_025","n_other_candidate_sites_025"))
     d[is.na(get(field)),(field):=-1L]
   report_data(d,name,keys[[name]])
  }
})
writeLines(trimws(report, which = "right"), "../report/data_review.txt")
# Tables recur throughout the evidence note. Escape source notes for Markdown.
md_table <- function(d) {
 d <- as.data.frame(d)
 for (field in names(d)) {
   x <- d[[field]]
   d[[field]] <- if(is.numeric(x)) format(round(x,3),trim=TRUE,scientific=FALSE,
     big.mark=if(field %in% c("sale_year","school_id","school_site_id")) "" else ",") else
     gsub("[|\n\r]"," ",as.character(x))
 }
 c(paste0("| ",paste(names(d),collapse=" | ")," |"),paste0("| ",paste(rep("---",ncol(d)),collapse=" | ")," |"),
 apply(d,1,function(x) paste0("| ",paste(x,collapse=" | ")," |")),"")
}
writeLines(c(
 "# School and housing data review", "",
 "The descriptive packet now includes 11,600 sales: 3,517 near selected closed schools and 8,083 near controls. Descriptive trends retain sales with incomplete property characteristics. All 10,921 sales in the earlier packet remain, with 679 added. School selection, geography, transaction weights, and the existing regression sample remain unchanged. The independent reconstruction still reproduces all 167,468 citywide complete-characteristics price-sample IDs.","",
 "## School programs, sites, and receiving schools", "",
 "The supplied February list contains 129 programs at 127 sites. Of the 47 programs that closed in 2013, the housing roster retains 30. Appendix A of the Consortium's 2015 report matches every closed program and all 53 receiving-school assignments (48 distinct receiving schools). It documents 15 closed programs whose buildings were taken over by receiving schools. CPS notices independently confirm that Fermi/South Shore and Garfield Park/Faraday already shared facilities. These 17 cases exactly match the closed programs excluded from the 30-school subset.","",
 "The 49 controls are a selected subset of the 82 listed programs that did not close in 2013. The remaining 33 have other recorded actions or receiving roles; their original notes are listed below. All 49 control IDs appear in the 2013-14 report card. Every candidate name also matches the original CPS February list, recovered from the contemporaneous ABC news PDF mirror and checked against the displayed page. The 33 non-control candidates include 18 receiving schools, five turnarounds, two delayed closures, four canceled closure proposals, three co-location cases, and Mason (its high-school program closed). The source notes govern these exclusions; individual final board reports for every non-closure action have not all been reverified. In particular, excluding the four canceled proposals is a comparison-group choice, not a failed merge.","",
 "School closure and a building ceasing school use are different outcomes. The 30-school restriction depends on post-decision building use and should not be described as all Chicago school closures or a random subset. Nor does it establish that a building remained vacant: later reuse is not measured here.","",
 "School coordinates transformed from longitude/latitude agree with the recorded StatePlane coordinates within 0.003 feet. No distinct candidate sites are less than 300 feet apart. Two pairs share exact coordinates: Humboldt/Duprey and the two Williams programs. Receiving schools use their 2013-14 locations, which matters when a program relocated. Every excluded closed program's receiving location is within 0.001 feet of its old location in these records.","",
 "The school cleaner now rejects duplicate 2013-14 school IDs instead of silently retaining the first record. The observed file has no duplicate IDs, so this adds protection without changing the cleaned data.","",
 "## Housing construction and assumptions", "",
 "The county extract covers Chicago assessor townships 70-77 and 2006-2025. The master keeps 428,582 single-parcel, non-condo residential transaction records, including transactions later excluded from prices. It excludes bundled sales, condos, and property classes outside the designated small-residential universe. County township coding defines city coverage.","",
 "Property characteristics join on exact parcel ID and sale year. Only single-building-card records enter the price sample. Legacy home-improvement exemptions update eligible pre-2021 characteristics; repeated identical active records count once, unresolved fields remain missing, and the original values remain available. These are administrative records, not verified measurements at the instant of sale. An exemption beginning in the sale year cannot establish whether renovation preceded that sale. Later assessor records are validation evidence, never values copied backward.","",
 "The price sample uses corrected property class, excluding class/use/apartment conflicts and mixed-use class 212. Class 211 means a whole 2-6-unit building. Descriptive prices no longer require complete core characteristics or an observed apartment-unit count. Of the 679 added comparison sales, 673 have blank apartment counts; six additional sales fail other completeness requirements. Apartment-building classification still comes from the assessor class. Building-size summaries use only observed positive floor area; five control sales have no usable floor area and still enter dollar-price summaries. The existing regression sample keeps its completeness requirements.","",
 "County sale-quality flags exclude recorded nominal prices at or below $10,000, selected deed types, and records flagged for the same parcel at the same price within 365 days. The threshold is fixed across years. The separate home_sale_quality_flags audit verifies that source flags survive every merge unchanged and explains overlapping exclusions; about 90% of flagged losses in the comparison have prices at or below $10,000. The $5,000 per-square-foot ceiling is a plausibility screen, not independent proof that each excluded transaction is erroneous. For this comparison, the annual price-per-square-foot cutoffs remain those computed at the 99.9th percentile of the existing citywide complete-characteristics sample. They are not recomputed on the enlarged sample. Price-per-square-foot screens apply only where positive floor area is observed; room consistency is checked only where both counts are observed. Missing values alone no longer exclude a sale. The annual cutoffs still remove one comparison sale per group in this snapshot. No lower-tail trim is applied.","",
 "Prices are converted using monthly Chicago CPI to the annual-average 2022 price level. Recorded sale dates mix refined transaction dates with monthly recording dates. Annual trends include the whole 2013 transition year; no exact-day treatment assignment is made.","",
 "Historical parcel-year coordinates are checked against their longitude/latitude projections. Missing coordinates stay in the broad master. Straight-line distances and nearest IDs were independently recomputed for all 239,254 study-period transactions against every candidate and receiving location, matching production within one millionth of a foot. All proximity counts match.","",
 "The comparison keeps sales within 1,320 feet of either treatment group, excludes opposite-group overlap, and excludes proximity to receiving schools or other February candidates. Same-status overlaps enter once, assigned to the nearest site. Excluding other schools narrows the geography; it does not prove there are no spillovers beyond a quarter mile. Distances do not identify attendance zones.","",
 "## Sequential sample counts", "",
 "Citywide counts precede geography. Group columns apply the same geographic comparison at every row. Restrictions accumulate; losses are not double-counted.","",
 md_table(dcast(audit$attrition,step+restriction~group,value.var="sales")),
 "## Sales added by removing completeness requirements", "",
 md_table(audit$sample_changes[,.(sales=sum(sales),complete_sales=sum(complete_sales),added=sum(added),added_blank_apartment_count=sum(added_blank_apartment_count),usable_area_sales=sum(usable_area_sales)),by=group]),
 "## Annual coverage", "",md_table(audit$selection),
 "Market-screened transactions retain the county flags, non-land restriction, and nominal price threshold but do not require complete characteristics. They remain restricted to the non-condo, single-parcel master. Counts have no housing-stock denominator and are not turnover rates.","",
 "## School sites contributing sales", "",md_table(audit$support[,.(school_site_id,school_names,group,schools,sales,parcels,pre_sales,post_sales)]),
 "## Closed programs excluded because school use continued", "",
 md_table(audit$schools[may2013_closed_47==1 & housing_treat_30==0,.(school_id,school_name_sy1213,notes)]),
 "## Other candidates excluded from the 49 controls", "",
 md_table(audit$schools[may2013_closed_47==0 & housing_control_49==0,.(school_id,school_name_sy1213,notes)]),
 "## Verification and source versions", "", md_table(audit$checks),md_table(audit$source_hashes),
 "The saved data report describes every summary table, its key, missingness, and distributions. In that report only, -1 marks undefined nearby-school counts for missing-coordinate records; the RDS preserves missing values. The separate housing-finalization audit checks all corrected fields against the independent exemption reconstruction and compares every selected row.","",
 "The review also found two reproducibility issues: raw exemption downloads wrote directly to their final paths, and the housing-finalization report still said school distances had not been constructed. Download recipes now publish only a completed transfer, and the stale report sentence has been corrected. Existing source snapshots remain unchanged.","",
 "## Sources and reproduction", "",
 "Run `make` in `tasks/audits/home_data_overview/code`. This task reads no regression outputs. The packet and PNGs are generated from `data_review.rds`.","",
 "- [Consortium 2015 report](https://consortium.uchicago.edu/sites/default/files/2018-10/School%20Closings%20Report.pdf), Appendix A, printed pp. 41-43; manual verification transcription in `code/school_reference.csv`.",
 "- [CPS Fermi/South Shore notice](https://schoolinfo.cps.edu/SchoolActions/Download.aspx?fid=1706).",
 "- [CPS Garfield Park/Faraday notice](https://schoolinfo.cps.edu/SchoolActions/Download.aspx?fid=1708).",
 "- [Original CPS February list, ABC mirror](https://dig.abclocal.go.com/wls/documents/cps-list.pdf); all 129 names and their ID crosswalk are recorded in `code/candidate_reference.csv`. The PDF is an image, so the transcription was checked visually, not inferred from an OCR count.",
 "- School rosters and report cards: supplied files owned by `tasks/raw_school_data`; original flags and notes are retained.",
 "- County parcel sales, residential characteristics, exemptions, parcel coordinates, and CPI: acquisition URLs and vintages in their production-task READMEs.",""),"../output/data_review.md")
