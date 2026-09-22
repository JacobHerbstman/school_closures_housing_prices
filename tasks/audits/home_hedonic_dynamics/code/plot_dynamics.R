# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_hedonic_dynamics/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(grid)})
a <- readRDS("../output/hedonic_dynamics.rds")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),
 panel.grid.major.x=element_blank(),legend.position="bottom",legend.title=element_blank(),
 strip.text=element_text(face="bold"),plot.title=element_text(face="bold",size=19),
 plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,22,18,22)))
labels <- c("All sales: fixed controls"="All sales: fixed premiums",
 "All sales: controls by year"="All sales: premiums vary by year",
 "Repeat sales: site effects"="Repeat sales: site effects",
 "Repeat sales: parcel effects"="Repeat sales: parcel effects",
 "Stable records: site effects"="Stable records: site effects",
 "Stable records: parcel effects"="Stable records: parcel effects")
colors <- c("All sales: fixed controls"="#52616B","All sales: controls by year"="#B34F36",
 "Repeat sales: site effects"="#24877C","Repeat sales: parcel effects"="#6A4C93",
 "Stable records: site effects"="#24877C","Stable records: parcel effects"="#6A4C93")
coefficients <- copy(a$coefficients)
coefficients[estimator=="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)x/1000),
 .SDcols=c("estimate","conf_low","conf_high")]
coefficients[estimator!="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),
 .SDcols=c("estimate","conf_low","conf_high")]
coefficients[,outcome:=factor(estimator,levels=c("OLS dollars","OLS log","PPML"),
 labels=c("Dollar OLS: thousands of dollars","Log OLS: percent","PPML: percent"))]
main_comparisons <- names(labels)[1:4]
pooled_data <- coefficients[design=="did" & comparison %in% main_comparisons]
pooled_data[,comparison:=factor(comparison,levels=rev(main_comparisons))]
pooled <- ggplot(pooled_data,aes(estimate,comparison,color=comparison))+
 geom_vline(xintercept=0,color="gray65",linetype=2)+
 geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation="y",width=.15,linewidth=.8)+
 geom_point(size=3)+facet_wrap(~outcome,nrow=1,scales="free_x")+
 scale_color_manual(values=colors,guide="none")+scale_y_discrete(labels=labels)+
 labs(title="Changing price premiums and comparing the same homes",
 subtitle="Pooled 2014-2018 versus 2008-2012 | Single-family homes and townhouses within half a mile",
 x=NULL,y=NULL,caption="Lines are school-site-clustered 95% intervals. All models weight transactions equally and include year effects.\nAll-sales models: 10,159 sales at 68 sites. Repeat-sale models: 1,778 sales of 762 parcels at 55 sites. Pooled models omit 2013.\nLog OLS concerns conditional log prices; PPML concerns conditional mean prices. Percentage estimates use 100 x [exp(coefficient) - 1].")

# Reuse one plotting function for the three comparisons, preserving the same axes within each outcome.
event_plot <- function(selected_comparisons,title,subtitle,caption) {
 d <- coefficients[design=="event" & comparison %in% selected_comparisons]
 d <- rbind(d,unique(d[,.(comparison,estimator,outcome)])[,`:=`(sale_year=2012L,estimate=0,conf_low=0,conf_high=0)],fill=TRUE)
 d[,comparison:=factor(comparison,levels=selected_comparisons)]
 setorder(d,comparison,estimator,sale_year)
 ggplot(d,aes(sale_year,estimate,color=comparison,group=comparison))+
  geom_hline(yintercept=0,color="gray65",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
  geom_errorbar(aes(ymin=conf_low,ymax=conf_high),position=position_dodge(.25),width=.12,alpha=.6)+
  geom_line(linewidth=.8)+geom_point(position=position_dodge(.25),size=1.8)+
  facet_wrap(~outcome,ncol=1,scales="free_y")+scale_color_manual(values=colors,labels=labels)+
  scale_x_continuous(breaks=2008:2018)+labs(title=title,subtitle=subtitle,x="Sale year",y="Difference relative to 2012",
  caption=paste0(caption,"\nSchool-site-clustered 95% intervals; 2012 reference. Every 2013 sale is retained. Prices are in 2022 dollars."))
}
varying <- event_plot(main_comparisons[1:2],"Allowing house-characteristic premiums to change each year",
 "Same 11,202 sales at 68 school sites | Same site and year effects | Same property variables",
 "Both specifications use size, age, rooms, bathrooms, class, type, quality and condition. Red allows their coefficients to vary by year.")
repeats <- event_plot(main_comparisons[c(1,3,4)],"Do the same homes appreciate differently?",
 "Gray: all 11,202 sales | Green and purple: the same 1,808 repeat-sale transactions",
 "Repeat parcels sell in both 2008-2012 and 2014-2018: 132 treated homes at 17 sites; 630 control homes at 38 sites.\nGreen retains site effects; purple uses parcel effects. Both retain fixed characteristic coefficients. Repeated sellers are selected.")
stable <- event_plot(names(labels)[5:6],"Repeat sales without recorded changes: a sensitivity check",
 "Same 1,478 sales of 633 parcels | 99 treated homes at 15 sites; 534 control homes at 38 sites",
 "Exclude repeat parcels with any recorded change in a controlled characteristic or a recorded improvement.\nStable records do not prove no renovation. These exclusions can select on post-closure outcomes; this is not the main sample.")
support_data <- copy(a$annual_support)
support_data[,panel:=paste(ifelse(sample=="All sales","Full estimation sample","Selected repeat-sale sample"),group,sep=" | ")]
support_data[,panel:=factor(panel,levels=c("Full estimation sample | Closed","Full estimation sample | Stayed open",
 "Selected repeat-sale sample | Closed","Selected repeat-sale sample | Stayed open"))]
# The required pre/post sales flank 2013; its sales must be additional transactions.
# Show those points, but do not connect them as a comparable repeat-sale count series.
support_data[,line_group:=paste(sample,ifelse(sample=="All sales","all",ifelse(sale_year<2013,"pre","post")))]
support <- ggplot(support_data,aes(sale_year,sales,color=sample))+
 geom_vline(xintercept=2013,color="gray70",linetype=3)+
 geom_line(data=support_data[sample=="All sales" | sale_year!=2013],aes(group=line_group),linewidth=.9)+
 geom_point(size=2)+geom_text(data=support_data[sale_year==2013 & sample!="Stable records"],
 aes(label=sales),nudge_x=.25,hjust=0,vjust=-.65,size=3.5,show.legend=FALSE)+
 facet_wrap(~panel,ncol=2,scales="free_y")+
 scale_color_manual(values=c("All sales"="#52616B","Repeat sales"="#6A4C93","Stable records"="#24877C"))+
 scale_x_continuous(breaks=2008:2018)+scale_y_continuous(limits=c(0,NA))+
 labs(title="The 2013 dip is specific to the repeat-sale sample",
 subtitle="Full-sample sales rise in 2013. Repeat parcels must sell in 2008-2012 AND 2014-2018; a 2013 sale is additional.",
 x="Sale year",y="Transactions",caption="Panels have different vertical scales; labels identify 2013 counts. All sales means the unchanged 11,202-sale estimation sample.\nThe repeat-sale rule favors transactions outside 2013. Its isolated 2013 points are not evidence of a market-wide sales collapse.\nStable records additionally exclude observed characteristic changes or improvements. None of these counts uses a housing-stock denominator.")

pdf("../output/hedonic_dynamics.pdf",width=13,height=9.5,onefile=TRUE,useDingbats=FALSE)
print(pooled);print(varying);print(repeats);print(support);print(stable)
# A compact numeric appendix keeps the pooled intervals and sample counts accessible.
grid.newpage()
grid.text("Pooled estimates and repeat-sale support",x=.05,y=.95,just="left",gp=gpar(fontsize=20,fontface="bold"))
table <- coefficients[design=="did"]
table[,comparison:=factor(comparison,levels=names(labels))]
setorder(table,comparison,outcome)
table[,result:=sprintf("%.1f [%.1f, %.1f]",estimate,conf_low,conf_high)]
table <- dcast(table,comparison~estimator,value.var="result")
grid.text("Estimate [95% interval]; dollars below are in thousands",x=.05,y=.90,just="left",gp=gpar(fontsize=12))
for(j in seq_along(c("Comparison","Dollar OLS","Log OLS (%)","PPML (%)"))) {
 grid.text(c("Comparison","Dollar OLS","Log OLS (%)","PPML (%)")[j],x=c(.05,.45,.64,.82)[j],y=.85,just="left",gp=gpar(fontsize=12,fontface="bold"))
}
for(i in seq_len(nrow(table))) {
 values <- c(labels[as.character(table$comparison[i])],table$`OLS dollars`[i],table$`OLS log`[i],table$PPML[i])
 for(j in seq_along(values)) grid.text(values[j],x=c(.05,.45,.64,.82)[j],y=.85-i*.065,just="left",gp=gpar(fontsize=11))
}
pre_p <- a$models[design=="event" & estimator=="OLS log"]
grid.text(paste(
 "Repeat definition: at least one eligible sale in 2008-2012 and one in 2014-2018. Same PIN and site throughout.",
 "Recorded characteristic changes: 25 of 132 treated repeat parcels; 68 of 630 control repeat parcels.",
 "Recorded improvements: 14 treated and 49 control repeat parcels. These groups can overlap.",
 "Fixed parcel effects remove time-invariant property differences, not renovations or selection into resale.",
 "Historical parcel splits/merges are not separately linked; unchanged PINs do not guarantee unchanged structures.",
 sprintf("All-sales annual log pre-test p-values: fixed premiums %.3f; year-specific premiums %.3f.",
  pre_p[comparison=="All sales: fixed controls",pretrend_p],pre_p[comparison=="All sales: controls by year",pretrend_p]),
 "The 2010 log-price dip remains with year-specific premiums. A non-rejecting joint test is not evidence of no pre-trend.",
 sep="\n\n"),x=.05,y=.40,just=c("left","top"),gp=gpar(fontsize=11))
dev.off()
ggsave("../output/pooled_comparisons.png",pooled,width=13,height=7.5,dpi=180,bg="white")
ggsave("../output/controls_by_year.png",varying,width=12,height=10,dpi=180,bg="white")
ggsave("../output/repeat_sales.png",repeats,width=12,height=10,dpi=180,bg="white")
ggsave("../output/sample_support.png",support,width=13,height=9.5,dpi=180,bg="white")
