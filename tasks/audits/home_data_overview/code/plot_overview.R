# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(patchwork);library(sf)})
audit <- readRDS("../output/data_review.rds")
colors <- c("Closed"="#AF493D","Stayed open"="#176D8A","Other candidate"="#939B9E")
theme_set(theme_minimal(base_size=13,base_family="sans") + theme(
 panel.grid.minor=element_blank(), panel.grid.major.x=element_blank(),
 plot.title=element_text(size=20,face="bold",color="#23343C",margin=margin(b=8)),
 plot.subtitle=element_text(size=12,color="#52616A",margin=margin(b=14)),
 plot.caption=element_text(size=10,color="#52616A",hjust=0,lineheight=1.15,margin=margin(t=16)),
 strip.text=element_text(face="bold",hjust=0,size=13),legend.position="bottom",legend.title=element_blank(),
 plot.title.position="plot",plot.caption.position="plot",
 plot.margin=margin(20,24,16,20),axis.title=element_text(size=11),panel.spacing=grid::unit(1.3,"lines")))
# Repeated time-series styling makes the group colors, dates, and axes consistent.
time_plot <- function(data, value, label) {
 ggplot(data,aes(sale_year,.data[[value]],color=group,shape=group,group=group))+
  geom_vline(xintercept=2013,linetype=3,color="#9FA9AE",linewidth=.5)+
  geom_line(linewidth=.9)+geom_point(size=2)+scale_color_manual(values=colors)+
  scale_shape_manual(values=c("Closed"=17,"Stayed open"=16))+
  scale_x_continuous(breaks=seq(2008,2018,2))+labs(x=NULL,y=label)
}
prices <- melt(audit$annual_prices,id.vars=c("group","sale_year"),measure.vars=c("mean_price","median_price"),variable.name="statistic")
prices[,statistic:=factor(statistic,levels=c("mean_price","median_price"),labels=c("Arithmetic mean","Median sale"))]
price_plot <- time_plot(prices,"value","Sale price (2022 dollars)")+facet_wrap(~statistic,nrow=1)+
 scale_y_continuous(labels=scales::label_dollar(scale=.001,suffix="k"),limits=c(0,NA))+
 labs(title="Housing prices before and after the closures",subtitle="Annual transaction prices near the selected closed and still-open schools, 2008-2018",
 caption="Each sale receives equal weight. Houses, townhouses, and apartment buildings; 11,600 sales. Missing characteristics do not exclude a sale.\nPrices use Chicago CPI and 2022 dollars. Dotted line marks 2013. These are descriptive trends, without regression adjustment.")
# Preserve the earlier complete-characteristics figure for its dated logbook entry.
complete_prices <- melt(audit$complete_prices,id.vars=c("group","sale_year"),measure.vars=c("mean_price","median_price"),variable.name="statistic")
complete_prices[,statistic:=factor(statistic,levels=c("mean_price","median_price"),labels=c("Arithmetic mean","Median sale"))]
complete_price_plot <- (price_plot %+% complete_prices)+labs(caption="Each sale receives equal weight. Houses, townhouses, and entire 2-6-unit apartment buildings; 10,921 sales.\nPrices use Chicago CPI and 2022 dollars. Dotted line marks 2013. These are descriptive trends, without regression adjustment.")
quantiles <- melt(audit$annual_prices,id.vars=c("group","sale_year"),measure.vars=c("p10","p25","median_price","p75","p90","p95"),variable.name="percentile")
quantiles[,percentile:=factor(percentile,levels=c("p10","p25","median_price","p75","p90","p95"),labels=c("10th percentile","25th percentile","Median","75th percentile","90th percentile","95th percentile"))]
distribution_plot <- time_plot(quantiles,"value","Sale price (2022 dollars)")+facet_wrap(~percentile,ncol=3,scales="free_y")+
 scale_y_continuous(labels=scales::label_dollar(scale=.001,suffix="k"),limits=c(0,NA))+
 labs(title="Where in the price distribution does growth occur?",subtitle="Compare both treatment groups within each panel; vertical scales differ across percentiles",
 caption="Percentiles are calculated separately within each group and year from the same descriptive price sample.\nThey describe the properties sold in that year; they do not track appreciation of a fixed set of homes.")
counts <- audit$annual_counts[stage %in% c(3,7)]
counts[,sample:=factor(stage,levels=c(3,7),labels=c("Market-screened transactions","Descriptive price sample"))]
count_plot <- time_plot(counts,"sales","Transactions per year")+facet_wrap(~sample,nrow=1)+
 scale_y_continuous(labels=scales::label_comma(),limits=c(0,NA))+
 labs(title="Sales volume and the price sample",subtitle="Same quarter-mile geography; compare counts before and after property eligibility and price screens",
 caption="Market-screened: county sale-quality flags, non-land sales, nominal price above $10,000; non-condo master universe.\nThe descriptive sample restricts property type and building records; price-per-sq.-ft. checks use observed floor area.\nThese are transaction counts, not turnover rates. No housing-stock denominator is used.")
composition <- copy(audit$composition)
apartments <- composition[property_type=="Apartment buildings (2-6 units)"]
mix_share <- time_plot(apartments,"share","Apartment buildings (% of sales)")+
 scale_y_continuous(labels=scales::label_percent(),limits=c(0,1))+labs(title="Apartment-building share")
type_prices <- time_plot(composition,"mean_price","Mean price (2022 dollars)")+facet_wrap(~property_type,nrow=1)+
 scale_y_continuous(labels=scales::label_dollar(scale=.001,suffix="k"),limits=c(0,NA))+labs(title="Prices within each property type")
size <- composition[,.(mean_sqft=weighted.mean(mean_sqft,usable_area_sales)),by=.(group,sale_year)]
size_plot <- time_plot(size,"mean_sqft","Mean building area (square feet)")+
 scale_y_continuous(labels=scales::label_comma(),limits=c(0,NA))+labs(title="Size of buildings sold")
mix_plot <- ((mix_share|size_plot)/type_prices)+plot_layout(guides="collect")+
 plot_annotation(title="The mix of properties sold",subtitle="Apartment buildings are whole-building transactions, not individual apartment prices",
 caption="Property type follows the assessor class; an observed apartment count is not required. Building-size means use available floor area.\nWithin-type means can still change with building size, condition, exact location, or the mix of parcels sold.")
mix_plot <- mix_plot & theme(legend.position="bottom",plot.title=element_text(size=16))
selection_plot <- time_plot(audit$selection,"retention","Market-screened sales retained (%)")+
 scale_y_continuous(labels=scales::label_percent(),limits=c(0,1))+
 labs(title="Sales retained for descriptive trends",subtitle="Fraction of market-screened transactions retained in each group and year",
 caption="The denominator is market-screened transactions in the same geographic comparison.\nLosses include mixed-use or conflicting property records, multiple building cards, and observed price or room inconsistencies.")
locations <- st_as_sf(audit$sites,coords=c("x","y"),crs=3435,remove=FALSE)
buffers <- st_buffer(locations[locations$group!="Other candidate",],1320)
hydro <- st_transform(st_read("../input/chicago_hydro.geojson",quiet=TRUE),3435)
stopifnot(all(st_is_valid(hydro)))
map_plot <- ggplot()+geom_sf(data=hydro,fill="#E4EFF3",color=NA)+geom_sf(data=buffers,aes(color=group),fill=NA,linewidth=.3,alpha=.6)+
 geom_point(data=audit$map_sales,aes(x,y,color=group),size=.25,alpha=.35)+
 geom_sf(data=locations,aes(color=group,shape=group),size=1.8)+
 scale_color_manual(values=colors)+scale_shape_manual(values=c("Closed"=17,"Stayed open"=16,"Other candidate"=4))+
 coord_sf(crs=3435,datum=NA,xlim=c(min(locations$x)-6000,max(locations$x)+15000),
   ylim=range(locations$y)+c(-4000,4000),expand=FALSE)+
 annotate("text",x=1206000,y=1903000,label="Lake\nMichigan",color="#607D8B",size=3.5,fontface="italic")+
 annotate("segment",x=1140000,xend=1150560,y=1820000,yend=1820000,linewidth=.6,color="#52616A")+
 annotate("text",x=1145280,y=1817500,label="2 miles",size=3,color="#52616A")+
 labs(x=NULL,y=NULL)+theme(axis.title=element_blank(),panel.grid=element_blank())
map_header <- ggplot()+xlim(0,1)+ylim(0,1)+theme_void()+
 annotate("text",x=.03,y=.7,label="The school comparison and nearby housing sales",hjust=0,size=6.5,fontface="bold",color="#23343C")+
 annotate("text",x=.03,y=.17,label="30 closed programs at 29 sites; 49 still-open schools. Circles show a quarter mile.",hjust=0,size=3.7,color="#52616A")
map_footer <- ggplot()+xlim(0,1)+ylim(0,1)+theme_void()+
 annotate("text",x=.03,y=.6,label="Colored dots show retained sales. Gray crosses are other schools on the February candidate list.\nDistances are straight-line distances to school buildings, not attendance areas or walking routes. North is up.",hjust=0,size=3.4,lineheight=1.4,color="#52616A")
map_plot <- (map_header/map_plot/map_footer)+plot_layout(heights=c(.12,1,.10))
support <- copy(audit$support)
support[,rank:=seq_len(.N),by=group]
support[,cumulative_share:=cumsum(sales)/sum(sales),by=group]
concentration <- ggplot(support,aes(rank,cumulative_share,color=group,shape=group))+
 geom_line(linewidth=1)+geom_point(size=1.6)+scale_color_manual(values=colors)+
 scale_shape_manual(values=c("Closed"=17,"Stayed open"=16))+
 scale_y_continuous(labels=scales::label_percent(),limits=c(0,1))+labs(x="School sites, ranked by total sales",y="Cumulative share of sales",title="Concentration across neighborhoods")+guides(color="none",shape="none")
site_year <- merge(audit$site_year,audit$support[,.(school_site_id,group)],by="school_site_id")
sparse <- site_year[,.(value=mean(sales<5)),by=.(group,sale_year)]
sparsity <- time_plot(sparse,"value","Sites with fewer than 5 sales (%)")+scale_y_continuous(labels=scales::label_percent(),limits=c(0,1))+
 labs(title="Sparse school-year cells")
support_plot <- (concentration|sparsity)+plot_layout(guides="collect")+
 plot_annotation(title="How much data comes from each neighborhood?",subtitle="All 78 physical comparison sites are included, including a site with no qualifying sales",
 caption="Sales enter with equal transaction weights, so high-volume neighborhoods contribute more.\nCarver Primary has no qualifying quarter-mile sales. Empty site-years count as sparse; no prices are imputed.")
support_plot <- support_plot & theme(legend.position="bottom",plot.title=element_text(size=16))
# Text pages introduce the records and choices without requiring a methods discussion.
cover <- ggplot()+xlim(0,1)+ylim(0,1)+theme_void()+
 annotate("rect",xmin=0,xmax=1,ymin=.88,ymax=1,fill="#176D8A")+
 annotate("text",x=.055,y=.94,label="CHICAGO  |  SCHOOLS & HOUSING",hjust=0,color="white",size=5,fontface="bold")+
 annotate("text",x=.055,y=.77,label="Start with the data",hjust=0,size=12,fontface="bold",color="#23343C")+
 annotate("text",x=.055,y=.65,label="School definitions, sample construction, and raw housing trends\n2008-2018  |  Descriptive research discussion",hjust=0,size=5,lineheight=1.5,color="#52616A")+
 annotate("text",x=.055,y=.48,label="30 closed schools     49 still-open schools     11,600 sales",hjust=0,size=5.5,fontface="bold",color="#176D8A")+
 annotate("text",x=.055,y=.32,label=paste("Both school groups come from the February 2013 closure-consideration list.",
 "The 30 closed programs exclude 17 whose facilities continued to house schools.",
 "The 49 controls exclude other listed schools with receiving roles or other actions.",sep="\n"),hjust=0,size=4.2,lineheight=1.55,color="#23343C")+
 annotate("text",x=.055,y=.13,label="Read the map and price distributions first, then sales counts, composition, and sample coverage.\nObserved prices, sales volume, and the properties that changed hands.",hjust=0,size=4,lineheight=1.5,color="#52616A")
assumptions <- ggplot()+xlim(0,1)+ylim(0,1)+theme_void()+
 annotate("text",x=.04,y=.94,label="Choices to keep in view",hjust=0,size=9,fontface="bold",color="#23343C")+
 annotate("text",x=.04,y=.81,label="School programs and school buildings",hjust=0,size=5,fontface="bold",color="#176D8A")+
 annotate("text",x=.04,y=.73,label="A program can close while its building remains a school. The 30-school subset reflects this distinction.\nIts selection is tied to building use after the closure decision; it is not a random subset of all 47 closures.",hjust=0,size=4,lineheight=1.5)+
 annotate("text",x=.04,y=.59,label="Geographic comparison",hjust=0,size=5,fontface="bold",color="#176D8A")+
 annotate("text",x=.04,y=.51,label="Retain sales within 1,320 feet of one treatment group. Exclude sales near both groups, or within\n1,320 feet of receiving schools or other candidates. Use receiving schools' 2013-14 locations.\nSame-group overlaps enter once, assigned to the nearest site. These restrictions define the comparison.",hjust=0,size=4,lineheight=1.5)+
 annotate("text",x=.04,y=.35,label="Housing records and prices",hjust=0,size=5,fontface="bold",color="#176D8A")+
 annotate("text",x=.04,y=.26,label="Single-parcel, non-condo sales only. Missing characteristics, including apartment counts, are retained.\nRoom checks use observed values. Price-per-square-foot checks use available floor area and annual\ncutoffs based on citywide sales with complete records. Building-size means use observed floor area.",hjust=0,size=4,lineheight=1.5)+
 annotate("text",x=.04,y=.09,label="Rising transaction prices can reflect appreciation, different properties selling, or changing neighborhood shares.\nAnnual counts have no housing-stock denominator. These figures describe the data; they do not identify a closure effect.",hjust=0,size=4,lineheight=1.5,color="#52616A")
# A compact count table connects source records to the plotted observations.
funnel <- dcast(audit$attrition,step+restriction~group,value.var="sales")
funnel[,label:=c("Recorded transactions","County price, deed, and repeat screens","Non-land price above $10,000", "Eligible type; single building card", "Missing characteristics allowed", "Room and price plausibility screens", "Annual price-per-square-foot cutoffs")]
funnel_plot <- ggplot()+xlim(0,1)+ylim(0,1)+theme_void()+
 annotate("text",x=.04,y=.94,label="From the source records to the comparison",hjust=0,size=8,fontface="bold",color="#23343C")+
 annotate("text",x=.04,y=.81,label="129 candidates = 47 closed in 2013 + 82 that did not close in 2013",hjust=0,size=5,color="#176D8A",fontface="bold")+
 annotate("text",x=.04,y=.71,label="Keep 30 closed programs after excluding 17 with continued school use.
Keep 49 controls after excluding 33 with other actions or receiving roles.
The control exclusions include four schools whose proposed closures were canceled.",hjust=0,size=4,lineheight=1.5)+
 annotate("text",x=c(.04,.62,.77,.92),y=.57,label=c("Housing records, 2008-2018","Citywide","Closed","Stayed open"),hjust=c(0,1,1,1),size=4,fontface="bold",color="#23343C")+
 geom_text(data=funnel,aes(x=.04,y=.55-step*.055,label=label),hjust=0,size=3.8)+
 geom_text(data=funnel,aes(x=.62,y=.55-step*.055,label=scales::comma(Citywide)),hjust=1,size=4,color="#52616A")+
 geom_text(data=funnel,aes(x=.77,y=.55-step*.055,label=scales::comma(Closed)),hjust=1,size=4,color=colors["Closed"])+
 geom_text(data=funnel,aes(x=.92,y=.55-step*.055,label=scales::comma(`Stayed open`)),hjust=1,size=4,color=colors["Stayed open"])+
 annotate("text",x=.04,y=.07,label="Group counts apply the same quarter-mile geography at every step. Citywide counts precede geography.
County screens exclude prices at or below $10,000, selected deeds, and same-parcel/same-price repeats within 365 days.
Restrictions accumulate. Final comparison: 3,517 + 8,083 = 11,600 transactions.",hjust=0,size=3.3,lineheight=1.4,color="#52616A")
pdf("../output/data_overview.pdf",width=11,height=8.5,onefile=TRUE,useDingbats=FALSE)
for(p in list(cover,funnel_plot,map_plot,price_plot,distribution_plot,count_plot,mix_plot,selection_plot,support_plot,assumptions)) print(p)
dev.off()
ggsave("../output/school_map.png",map_plot,width=10,height=9,dpi=200,bg="white")
ggsave("../output/price_trends.png",price_plot,width=11,height=7,dpi=200,bg="white")
ggsave("../output/price_distribution.png",distribution_plot,width=11,height=8,dpi=200,bg="white")
ggsave("../output/sales_counts.png",count_plot,width=11,height=7,dpi=200,bg="white")
ggsave("../output/property_mix.png",mix_plot,width=11,height=9,dpi=200,bg="white")
ggsave("../output/selection.png",selection_plot,width=11,height=7,dpi=200,bg="white")
ggsave("../output/site_support.png",support_plot,width=11,height=7,dpi=200,bg="white")

ggsave("../output/complete_characteristics_price_trends.png",complete_price_plot,width=11,height=7,dpi=200,bg="white")
