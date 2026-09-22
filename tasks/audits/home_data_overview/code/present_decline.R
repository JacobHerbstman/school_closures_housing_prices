# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(patchwork)})
source("../../../shared/code/report_data.R")
a <- readRDS("../output/late_decline.rds")
report <- capture.output({
 keys <- list(pre_prices="school_site_id",pre_price_counts=c("group","price_group","sale_year"),pre_price_definition="cutoff",annual=c("group","sale_year"),site_year=c("group","school_site_id","sale_year"),changes=c("group","school_site_id","start_year"),omissions=c("omitted_site","sale_year"),composition=c("group","sale_year","property_type"),monthly=c("group","sale_year","sale_month"),expensive="row_id",coverage=c("school_site_id","sale_year"),fixed=c("group","sale_year"))
 for(n in names(keys)) report_data(a[[n]],n,keys[[n]])
})
writeLines(trimws(report,which="right"),"../report/late_decline.txt")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),legend.position="bottom",legend.title=element_blank(),plot.title=element_text(face="bold"),plot.caption=element_text(hjust=0),plot.margin=margin(20,20,20,20)))
p <- melt(a$fixed[group=="Closed"],id.vars=c("group","sale_year"),measure.vars=c("observed_mean","fixed_mean"))
p[,series:=fifelse(variable=="observed_mean","Actual transaction mix","Hold each site's 2016 sales weight")]
fixed_plot <- ggplot(p,aes(sale_year,value,color=series))+geom_line(linewidth=1)+geom_point(size=3)+
 scale_x_continuous(breaks=2016:2018)+scale_y_continuous(labels=scales::label_dollar())+
 labs(title="The late decline reverses when neighborhood weights are held fixed",subtitle="Treated group, quarter-mile sample; all 29 treated sites observed in each year",x=NULL,y="Mean sale price (2022 dollars)",
 caption="Fixed weights use each site's share of treated sales in 2016; within-site transaction means still vary.\nThis isolates changing neighborhood shares. It is not a repeat-sales or constant-property price index.")
ids <- a$changes[group=="Closed" & start_year==2016][1:4,school_site_id]
s <- copy(a$site_year[school_site_id %in% ids & sale_year>=2015])
s[,school:=sub(" Elementary School$","",school_names)]
counts <- ggplot(s,aes(sale_year,sales,color=school))+geom_line(linewidth=1)+geom_point(size=2)+scale_x_continuous(breaks=2015:2018)+labs(title="Fewer sales in expensive school neighborhoods",x=NULL,y="Qualifying sales")
prices <- ggplot(s,aes(sale_year,mean,color=school))+geom_line(linewidth=1)+geom_point(size=2)+scale_x_continuous(breaks=2015:2018)+scale_y_continuous(labels=scales::label_dollar(scale=.001,suffix="k"))+labs(title="Their average prices do not fall together",x=NULL,y="Mean price (2022 dollars)")
site_plot <- (counts/prices)+plot_layout(guides="collect")+plot_annotation(title="Which neighborhoods contribute to the decline?",caption="Four largest negative contributions to the pooled treated mean, 2016-2018.\nContribution changes include both the site's prices and its share of all treated sales; quarter-mile sample.")
q <- melt(a$annual[sale_year>=2015],id.vars=c("group","sale_year"),measure.vars=c("mean","median","p75","p95"))
dist_plot <- ggplot(q,aes(sale_year,value,color=group))+geom_line(linewidth=1)+geom_point(size=2)+facet_wrap(~variable,scales="free_y")+
 scale_color_manual(values=c("Closed"="#AF493D","Stayed open"="#176D8A"))+scale_x_continuous(breaks=2015:2018)+scale_y_continuous(labels=scales::label_dollar(scale=.001,suffix="k"))+
 labs(title="The decline is strongest below the very top of the distribution",subtitle="Quarter-mile descriptive sample; percentiles calculated within each group and year",x=NULL,y="Sale price (2022 dollars)",caption="The treated median is nearly unchanged from 2017 to 2018, while the mean continues falling.\nThese statistics describe changing transactions, not the appreciation of the same homes.")
pdf("../output/late_decline.pdf",width=11,height=8.5,useDingbats=FALSE)
print(fixed_plot);print(site_plot);print(dist_plot)
dev.off()
