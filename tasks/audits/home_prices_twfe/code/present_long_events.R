# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
# property_sample <- "all"
# radius_miles <- 0.25
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L)
property_sample <- args[1]
radius_miles <- as.numeric(args[2])
stopifnot(radius_miles %in% c(0.25,0.5),property_sample=="single_family" || radius_miles==0.25)
radius_suffix <- if(radius_miles==0.25) "" else "_0.5"
stopifnot(property_sample %in% c("all","single_family"))
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
source("../../../shared/code/report_data.R")
a <- readRDS(if(property_sample=="single_family") paste0("../output/single_family_events",radius_suffix,".rds") else "../output/long_events.rds")
writeLines(trimws(capture.output({report_data(a$coefficients,"coefficients",c("model","term"));report_data(a$summaries,"summaries","model");report_data(a$support,"support",c("group","sale_year"))}),which="right"),if(property_sample=="single_family") paste0("../report/single_family_events",radius_suffix,".txt") else "../report/long_events.txt")
d <- copy(a$coefficients)
d <- rbind(d,data.table(model=a$summaries$model,sale_year=2012,estimate=0,conf_low=0,conf_high=0),fill=TRUE)
d[,outcome:=factor(fifelse(grepl("dollars$",model),"Price (thousands of 2022 dollars)","Log price"),levels=c("Log price","Price (thousands of 2022 dollars)"))]
d[,controls:=factor(fifelse(grepl("hedonic",model),"With property controls","Without property controls"),levels=c("Without property controls","With property controls"))]
d[grepl("dollars$",model),c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)x/1000),.SDcols=c("estimate","conf_low","conf_high")]
setorder(d,model,sale_year)
p <- ggplot(d,aes(sale_year,estimate))+
 annotate("rect",xmin=2012.5,xmax=2013.5,ymin=-Inf,ymax=Inf,fill="gray94")+
 geom_hline(yintercept=0,linetype=2,color="gray55")+geom_line(color="#176D8A",linewidth=.7)+
 geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.15,color="#176D8A")+geom_point(color="#176D8A",size=1.8)+
 facet_grid(outcome~controls,scales="free_y")+scale_x_continuous(breaks=if(property_sample=="single_family") seq(2008,2018,2) else c(2008,2010,2012,2014,2016,2018,2020,2023))+
 labs(title=if(property_sample=="single_family") "Single-family homes: event studies, 2008-2018" else "Chicago school closures: event studies through 2023",subtitle=paste0(format(a$summaries$observations[1],big.mark=","),if(property_sample=="single_family") " houses/townhouses with complete characteristics" else " complete-characteristics sales", " | ",radius_miles," mile | Equal transaction weights"),
 x="Sale year",y="Treated-control difference relative to 2012",
 caption="School-site and year fixed effects in every panel. Pointwise 95% confidence intervals cluster by school site.\n2012 is the reference; shaded 2013 is the transition year. Property controls match the earlier event studies.\nThese descriptive regression comparisons remain subject to the pre-trend and anticipation concerns.")+
 theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),plot.title=element_text(face="bold"),plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,18,18,18),strip.text=element_text(face="bold"))
ggsave(if(property_sample=="single_family") paste0("../output/event_studies_single_family",radius_suffix,".png") else "../output/event_studies_through_2023.png",p,width=12,height=9,dpi=180,bg="white")
ggsave(if(property_sample=="single_family") paste0("../output/event_studies_single_family",radius_suffix,".pdf") else "../output/event_studies_through_2023.pdf",p,width=12,height=9)
