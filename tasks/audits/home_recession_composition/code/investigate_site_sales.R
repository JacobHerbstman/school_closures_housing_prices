# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_recession_composition/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
source("../../../shared/code/report_data.R")
a <- readRDS("../output/composition.rds")
distress <- readRDS("../input/distress.rds")

# Follow the five largest positive between-site contributions identified in
# the previous decomposition. This selection is descriptive, not a new sample.
sites <- a$decomposition[group=="Closed"][order(-between_sites)][1:5,.(school_site_id,school_names)]
sites[,site:=fcase(grepl("Trumbull",school_names),"Trumbull",grepl("William H King",school_names),"King",
 grepl("Peabody",school_names),"Peabody",grepl("Duprey",school_names),"Duprey / Humboldt",
 grepl("Near North",school_names),"Near North")]
stopifnot(!anyNA(sites$site),!anyDuplicated(sites$school_site_id),nrow(sites)==5L,
 !anyDuplicated(a$sales$row_id),!anyDuplicated(distress$records$row_id),
 all(a$sales$row_id %in% distress$records$row_id))

# Four nested transaction samples, all using the same spatial exclusions.
# The first already requires a single-parcel, single-card, single-family sale;
# it is before price and county-quality screens, not all neighborhood deeds.
before <- distress$records[,.(row_id,pin,school_site_id,sale_year,group,in_packet)]
stopifnot(all(before[row_id %in% a$sales$row_id,in_packet]))
stages <- rbind(before[,.(row_id,pin,school_site_id,sale_year,group,stage="Before price / quality screens")],
 before[in_packet==TRUE,.(row_id,pin,school_site_id,sale_year,group,stage="Clean price sample")],
 a$sales[,.(row_id,pin,school_site_id,sale_year,group,stage="Complete characteristics")],
 a$sales[assessment_usable==TRUE,.(row_id,pin,school_site_id,sale_year,group,stage="Usable 2006 assessment")])
stages[,area_set:=fcase(school_site_id %in% sites$school_site_id,"Five selected treated sites",
 group=="Closed","Other treated sites",default="Control sites")]
annual_counts <- stages[,.(sales=.N,parcels=uniqueN(pin)),by=.(area_set,sale_year,stage)]
site_counts <- stages[school_site_id %in% sites$school_site_id,
 .(sales=.N,parcels=uniqueN(pin)),by=.(school_site_id,sale_year,stage)]
# One site label per school-site identifier; every selected site has sales in
# each year and sample, so absent cells must be investigated, not interpolated.
site_counts <- merge(site_counts,sites[,.(school_site_id,site)],by="school_site_id",all.x=TRUE)
stopifnot(nrow(site_counts)==5L*11L*4L,!anyNA(site_counts$site))

# One raw names record per transaction. Keep only aggregate name counts in the
# saved audit; normalized names are not unique people or beneficial owners.
sales <- copy(a$sales[assessment_usable==TRUE & school_site_id %in% sites$school_site_id])
sales <- merge(sales,sites[,.(school_site_id,site)],by="school_site_id",all.x=TRUE)
raw <- fread("../input/raw_sales.csv",colClasses="character",
 select=c("row_id","sale_buyer_name","sale_seller_name"))
stopifnot(!anyDuplicated(raw$row_id),all(sales$row_id %in% raw$row_id))
sales <- merge(sales,raw,by="row_id",all.x=TRUE)
sales[,buyer:=trimws(gsub(" +"," ",gsub("[^A-Z0-9 ]"," ",toupper(sale_buyer_name))))]
sales[,seller:=trimws(gsub(" +"," ",gsub("[^A-Z0-9 ]"," ",toupper(sale_seller_name))))]
sales[,quarter:=(as.integer(format(sale_date,"%m"))-1L)%/%3L+1L]
stopifnot(!anyDuplicated(sales$row_id),!anyNA(sales$quarter),
 all(sales[sale_year %in% 2011:2012,buyer_known & seller_known]))
party_counts <- sales[sale_year %in% 2011:2012,.(sales=.N,parcels=uniqueN(pin),
 known_buyers=sum(buyer_known),distinct_buyer_names=uniqueN(buyer[buyer_known]),
 maximum_sales_per_buyer_name=max(table(buyer[buyer_known])),
 known_sellers=sum(seller_known),distinct_seller_names=uniqueN(seller[seller_known]),
 maximum_sales_per_seller_name=max(table(seller[seller_known])),
 organization_buyers=sum(organization_buyer),broad_bank_sellers=sum(broad_seller),
 other_known_sellers=sum(seller_known & !broad_seller)),by=sale_year]
seller_counts <- sales[sale_year %in% 2011:2012,.N,by=.(sale_year,seller_type)]
properties <- sales[,.(sales=.N,parcels=uniqueN(pin),
 median_age=as.numeric(median(age_at_sale)),median_sqft=as.numeric(median(res_char_bldg_sf)),
 median_initial=median(initial_assessed_total),median_price=median(price),
 newest_building_year=max(res_char_yrblt),built_since_2007=sum(res_char_yrblt>=2007),
 townhouses=sum(townhouse),broad_bank_sellers=sum(broad_seller),
 organization_buyers=sum(organization_buyer)),by=.(school_site_id,site,sale_year)]
quarterly <- sales[sale_year %in% 2011:2012,.(sales=.N),by=.(sale_year,quarter)]
stopifnot(nrow(quarterly)==8L,party_counts[sale_year==2011,sales]==28L,
 party_counts[sale_year==2012,sales]==66L)
sources <- data.table(source=c("../output/composition.rds","../input/distress.rds","../input/raw_sales.csv"))
sources[,sha256:=vapply(source,digest::digest,character(1),file=TRUE,algo="sha256")]
setorder(sites,school_site_id);setorder(annual_counts,area_set,sale_year,stage)
setorder(site_counts,school_site_id,sale_year,stage);setorder(party_counts,sale_year)
setorder(seller_counts,sale_year,seller_type);setorder(properties,school_site_id,sale_year)
setorder(quarterly,sale_year,quarter)
saveRDS(list(sites=sites,annual_counts=annual_counts,site_counts=site_counts,
 party_counts=party_counts,seller_counts=seller_counts,properties=properties,
 quarterly=quarterly,sources=sources),"../output/site_sales.rds")
writeLines(trimws(capture.output({
 cat("RDS SHA-256:",digest::digest(file="../output/site_sales.rds",algo="sha256"),"\n")
 report_data(sites,"sites","school_site_id")
 report_data(annual_counts,"annual_counts",c("area_set","sale_year","stage"))
 report_data(site_counts,"site_counts",c("school_site_id","sale_year","stage"))
 report_data(party_counts,"party_counts","sale_year")
 report_data(seller_counts,"seller_counts",c("sale_year","seller_type"))
 report_data(properties,"properties",c("school_site_id","sale_year"))
 report_data(quarterly,"quarterly",c("sale_year","quarter"))
 report_data(sources,"sources","source")
}),which="right"),"../report/site_sales.txt")

counts <- site_counts[stage=="Usable 2006 assessment"]
counts[,site:=factor(site,levels=c("Trumbull","King","Duprey / Humboldt","Peabody","Near North"))]
p <- ggplot(counts,aes(sale_year,sales))+
 geom_vline(xintercept=2012,color="#E2BCA6",linewidth=.6)+
 geom_line(color="#287C8E",linewidth=.8)+geom_point(color="#287C8E",size=2)+
 geom_point(data=counts[sale_year==2012],color="#B34F36",size=3)+
 geom_text(data=counts[sale_year %in% 2010:2013],aes(label=sales),vjust=-.8,size=3.8)+
 facet_wrap(~site,ncol=2)+scale_x_continuous(breaks=seq(2008,2018,2))+
 scale_y_continuous(limits=c(0,31),breaks=seq(0,30,10))+
 labs(title="2012 brings more sales, following a quiet 2011",
 subtitle="Single-family homes and townhouses with usable 2006 assessments | Half-mile school areas",
 x="Sale year",y="Transactions",
 caption="Five areas selected because their rising shares contribute most to the 2011-2012 mean-assessment increase.\nCombined counts: 39 in 2010, 28 in 2011, 66 in 2012 and 65 in 2013. Each panel uses the same scale.\nThese are counts in our selected sample, not turnover rates for the neighborhood housing stock.")+
 theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),
 strip.text=element_text(face="bold",size=13),plot.title=element_text(face="bold",size=19),
 plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,22,18,22))
ggsave("../output/site_sales.png",p,width=11,height=8.5,dpi=160,bg="white")
ggsave("../output/site_sales.pdf",p,width=11,height=8.5)
print(annual_counts[sale_year %in% 2010:2013])
print(party_counts);print(quarterly);print(properties[sale_year %in% 2011:2012])
