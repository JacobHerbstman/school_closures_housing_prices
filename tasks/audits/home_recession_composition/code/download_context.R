# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_recession_composition/code")
suppressPackageStartupMessages({library(curl);library(rvest);library(jsonlite)})
download_dir <- tempfile("context_download_",tmpdir="../temp")
dir.create(download_dir)
curl_download("https://www.housingstudies.org/data-portal/browse/?indicator=foreclosures-100-residential-parcel",
 file.path(download_dir,"ihs_foreclosures.html"),quiet=TRUE,handle=new_handle(timeout=120))
table <- read_html(file.path(download_dir,"ihs_foreclosures.html")) |> html_element("table#focus") |> html_table(convert=FALSE)
stopifnot(nrow(table)==78L,"Chicago Total" %in% table$Geography,
 "2010" %in% names(table),"2012" %in% names(table),!anyDuplicated(table$Geography))
curl_download("https://data.cityofchicago.org/resource/igwz-8jzy.geojson?$limit=100",
 file.path(download_dir,"community_areas.geojson"),quiet=TRUE,handle=new_handle(timeout=120))
areas <- fromJSON(file.path(download_dir,"community_areas.geojson"))
stopifnot(areas$type=="FeatureCollection",nrow(areas$features)==77L,
 !anyDuplicated(areas$features$properties$area_numbe))
sources <- data.frame(publisher=c("DePaul Institute for Housing Studies","City of Chicago"),
 filename=c("ihs_foreclosures.html","community_areas.geojson"),
 url=c("https://www.housingstudies.org/data-portal/browse/?indicator=foreclosures-100-residential-parcel",
 "https://data.cityofchicago.org/resource/igwz-8jzy.geojson?$limit=100"))
sources$sha256 <- vapply(file.path(download_dir,sources$filename),digest::digest,character(1),file=TRUE,algo="sha256")
write_json(list(retrieved_utc=format(Sys.time(),tz="UTC",format="%Y-%m-%dT%H:%M:%SZ"),sources=sources),
 file.path(download_dir,"source.json"),pretty=TRUE,auto_unbox=TRUE)
# All bytes are validated before one archive replaces the published snapshot.
archive <- file.path(normalizePath("../temp"),paste0(basename(download_dir),".tar.gz"))
task_code <- getwd();setwd(download_dir)
tar(archive,files=sort(list.files()),compression="gzip",tar="internal")
setwd(task_code)
stopifnot(length(untar(archive,list=TRUE))==3L,file.rename(archive,"../output/context_snapshot.tar.gz"))
