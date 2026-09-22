# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_initial_assessment/code")
suppressPackageStartupMessages({library(data.table);library(jsonlite);library(curl)})
source("../../../shared/code/report_data.R")
sales <- readRDS("../input/hedonic_dynamics.rds")$sales
pins <- sort(unique(sales$pin))
stopifnot(length(pins)>0L,all(grepl("^[0-9]{14}$",pins)))

# The fixed 2006 tax year precedes every outcome and the recession. Save the
# original responses and metadata together; downstream changes reuse this extract.
download_dir <- tempfile("assessment_download_",tmpdir="../temp")
dir.create(download_dir)
curl_download("https://datacatalog.cookcountyil.gov/api/views/uzyt-m557.json",
 file.path(download_dir,"metadata.json"),quiet=TRUE,handle=new_handle(timeout=120))
metadata <- fromJSON(file.path(download_dir,"metadata.json"))
stopifnot(metadata$id=="uzyt-m557",all(c("pin","year","class","mailed_tot","mailed_bldg","mailed_land") %in% metadata$columns$fieldName))
queries <- list(); responses <- list()
for(batch in seq_len(ceiling(length(pins)/500))) {
 batch_pins <- pins[seq.int((batch-1L)*500L+1L,min(batch*500L,length(pins)))]
 where <- paste0("year=2006 AND pin in (",paste(sprintf("'%s'",batch_pins),collapse=","),")")
 url <- paste0("https://datacatalog.cookcountyil.gov/resource/uzyt-m557.json?$where=",
  URLencode(where,reserved=TRUE),"&$order=pin&$limit=501")
 filename <- sprintf("batch_%02d.json",batch)
 curl_download(url,file.path(download_dir,filename),quiet=TRUE,handle=new_handle(timeout=120))
 received <- as.data.table(fromJSON(file.path(download_dir,filename)))
 stopifnot(nrow(received)>0L,nrow(received)<=length(batch_pins),!anyDuplicated(received$pin),
  all(received$pin %in% batch_pins),all(received$year=="2006"))
 queries[[batch]] <- data.table(batch,filename,url,requested_pins=length(batch_pins),received_rows=nrow(received),
  sha256=digest::digest(file=file.path(download_dir,filename),algo="sha256"))
 responses[[batch]] <- received
 cat("Batch",batch,":",nrow(received),"of",length(batch_pins),"PINs found\n")
}
assessments <- rbindlist(responses,fill=TRUE)
stopifnot(!anyDuplicated(assessments$pin),!anyDuplicated(assessments$row_id),all(assessments$pin %in% pins))
fwrite(rbindlist(queries),file.path(download_dir,"queries.csv"))
fwrite(data.table(pin=pins),file.path(download_dir,"requested_pins.csv"))
write_json(list(publisher="Cook County Assessor's Office",dataset="uzyt-m557",tax_year=2006,
 retrieved_utc=format(Sys.time(),tz="UTC",format="%Y-%m-%dT%H:%M:%SZ"),
 metadata_sha256=digest::digest(file=file.path(download_dir,"metadata.json"),algo="sha256"),
 sales_sha256=digest::digest(file="../input/hedonic_dynamics.rds",algo="sha256")),
 file.path(download_dir,"source.json"),auto_unbox=TRUE,pretty=TRUE)

# Package only validated original responses. A transfer/parse failure above leaves
# the previous published snapshot untouched; rename is on the same filesystem.
archive_path <- file.path(normalizePath("../temp"),paste0(basename(download_dir),".tar.gz"))
task_code <- getwd()
setwd(download_dir)
tar(archive_path,files=sort(list.files()),compression="gzip",tar="internal")
setwd(task_code)
stopifnot(length(untar(archive_path,list=TRUE))==length(list.files(download_dir)))
stopifnot(file.rename(archive_path,"../output/assessments_2006_snapshot.tar.gz"))
writeLines(trimws(capture.output({
 cat("Source snapshot SHA-256:",digest::digest(file="../output/assessments_2006_snapshot.tar.gz",algo="sha256"),"\n")
 report_data(assessments,"assessments",c("pin","year"))
 report_data(rbindlist(queries),"queries","batch")
}),which="right"),"../report/assessment_source.txt")
