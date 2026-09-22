# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_initial_assessment/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(grid)})
a <- readRDS("../output/initial_assessment.rds")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),
 panel.grid.major.x=element_blank(),legend.position="bottom",legend.title=element_blank(),
 strip.text=element_text(face="bold"),plot.title=element_text(face="bold",size=19),
 plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,22,18,22)))
labels <- c("All sales: existing model"="Full sample: existing model",
 "Matched: existing model"="Matched sample: existing model",
 "Matched: initial value"="Add initial value: fixed coefficient",
 "Matched: initial value by year"="Add initial value: coefficient by year",
 "Matched: all premiums by year"="All premiums vary by year")
colors <- c("All sales: existing model"="#929AA0","Matched: existing model"="#52616B",
 "Matched: initial value"="#AA7A28","Matched: initial value by year"="#B34F36",
 "Matched: all premiums by year"="#24877C")
coefficients <- copy(a$coefficients)
coefficients[estimator=="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)x/1000),
 .SDcols=c("estimate","conf_low","conf_high")]
coefficients[estimator!="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),
 .SDcols=c("estimate","conf_low","conf_high")]
coefficients[,outcome:=factor(estimator,levels=c("OLS dollars","OLS log","PPML"),
 labels=c("Dollar OLS: thousands of 2022 dollars","Log OLS: percent","PPML: percent"))]

event_plot <- function(selected,title,subtitle,caption) {
 d <- coefficients[design=="event" & comparison %in% selected]
 d <- rbind(d,unique(d[,.(comparison,estimator,outcome)])[,`:=`(sale_year=2012L,estimate=0,conf_low=0,conf_high=0)],fill=TRUE)
 d[,comparison:=factor(comparison,levels=selected)]
 setorder(d,comparison,estimator,sale_year)
 ggplot(d,aes(sale_year,estimate,color=comparison,group=comparison))+
  geom_hline(yintercept=0,color="gray65",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
  geom_errorbar(aes(ymin=conf_low,ymax=conf_high),position=position_dodge(.22),width=.1,alpha=.6)+
  geom_line(linewidth=.85)+geom_point(position=position_dodge(.22),size=1.8)+
  facet_wrap(~outcome,ncol=1,scales="free_y")+scale_color_manual(values=colors,labels=labels)+
  scale_x_continuous(breaks=2008:2018)+labs(title=title,subtitle=subtitle,x="Sale year",
  y="Treated-control difference relative to 2012",caption=paste0(caption,
  "\nSchool-site-clustered 95% intervals; 2012 reference. Annual models retain 2013. Each transaction has equal weight."))
}
main <- event_plot(names(labels)[c(2,4)],"Initial property value does not remove the pre-closure dip",
 "Same 10,452 sales at 67 sites | Single-family homes and townhouses within half a mile",
 "Red adds log(2006 mailed total assessment) with a separate coefficient each year. Other property coefficients remain fixed.\nBoth models include the same property characteristics, school-site effects and year effects.")
sample_effect <- event_plot(names(labels)[1:2],"Separating assessment coverage from the adjustment",
 "Existing model in both lines | Full sample: 11,202 sales | Assessment sample: 10,452 sales",
 "The assessment sample requires a positive 2006 total and building value and a single-family property class in 2006.\n750 transactions are excluded from this check; the working sales pipeline is unchanged.")
all_premiums <- event_plot(names(labels)[4:5],"Also letting house-characteristic premiums change each year",
 "Same 10,452 sales | Both models allow the initial-value coefficient to vary by year",
 "Green additionally varies all size, age, rooms, bathrooms, class, type, quality and condition coefficients by year.\nThe 2010 log-price dip remains in both specifications.")
pooled_data <- coefficients[design=="did"]
pooled_data[,comparison:=factor(comparison,levels=rev(names(labels)))]
pooled <- ggplot(pooled_data,aes(estimate,comparison,color=comparison))+
 geom_vline(xintercept=0,color="gray65",linetype=2)+
 geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation="y",width=.15,linewidth=.8)+
 geom_point(size=3)+facet_wrap(~outcome,nrow=1,scales="free_x")+
 scale_color_manual(values=colors,guide="none")+scale_y_discrete(labels=labels)+
 labs(title="Initial value changes the dollar estimate more than the log estimate",
 subtitle="Pooled 2014-2018 versus 2008-2012 | All 95% intervals include zero",
 x=NULL,y=NULL,caption="The first row uses 10,159 sales; all other rows use the same 9,462 sales. Pooled models omit 2013.\nInitial value is log(2006 mailed total assessment). A fixed coefficient adjusts price levels; yearly coefficients allow different paths by initial value.\nAll models include site and year effects. Intervals cluster by school site; transactions have equal weights. Percentages are 100 x [exp(coefficient) - 1].")

mix <- melt(a$annual_support,id.vars=c("group","sale_year"),measure.vars=c("mean_initial_value","median_initial_value"),
 variable.name="statistic",value.name="initial_value")
mix[,statistic:=factor(statistic,levels=c("mean_initial_value","median_initial_value"),
 labels=c("Mean 2006 assessment of homes sold","Median 2006 assessment of homes sold"))]
initial_mix <- ggplot(mix,aes(sale_year,initial_value/1000,color=group))+
 geom_vline(xintercept=2013,color="gray70",linetype=3)+geom_line(linewidth=.95)+geom_point(size=2)+
 facet_wrap(~statistic,ncol=1)+scale_x_continuous(breaks=2008:2018)+
 scale_color_manual(values=c("Closed"="#B34F36","Stayed open"="#287C8E"))+
 labs(title="The initial value of homes sold changes across years",
 subtitle="Every home keeps its own 2006 assessment; movement reflects which homes sell",
 x="Sale year",y="2006 assessed value, thousands of dollars",
 caption="These are assessments, not market values or sale prices. Both panels use the 10,452 transactions with usable initial assessments.\nThe 2012 treated sales have higher initial values than nearby years. Year-specific assessment controls still leave a large 2010 log-price gap.\nA fixed assessment measures initial property value imperfectly; it does not measure foreclosure exposure or later renovations.")

pdf("../output/initial_assessment.pdf",width=13,height=9.5,onefile=TRUE,useDingbats=FALSE)
print(main);print(pooled);print(sample_effect);print(all_premiums);print(initial_mix)
grid.newpage()
grid.text("Coverage, specification and numerical results",x=.05,y=.95,just="left",gp=gpar(fontsize=20,fontface="bold"))
grid.text("Pooled estimate [95% interval]; dollar estimates below are in thousands",x=.05,y=.90,just="left",gp=gpar(fontsize=12))
table <- coefficients[design=="did"]
table[,comparison:=factor(comparison,levels=names(labels))]
table[,result:=sprintf("%.1f [%.1f, %.1f]",estimate,conf_low,conf_high)]
table <- dcast(table,comparison~estimator,value.var="result")
for(j in 1:4) grid.text(c("Specification","Dollar OLS","Log OLS (%)","PPML (%)")[j],
 x=c(.05,.46,.65,.83)[j],y=.85,just="left",gp=gpar(fontsize=12,fontface="bold"))
for(i in seq_len(nrow(table))) {
 values <- c(labels[as.character(table$comparison[i])],table$`OLS dollars`[i],table$`OLS log`[i],table$PPML[i])
 for(j in 1:4) grid.text(values[j],x=c(.05,.46,.65,.83)[j],y=.85-i*.055,just="left",gp=gpar(fontsize=10.5))
}
matched <- a$coverage[assessment_status=="Usable 2006 assessment"]
pre <- a$models[design=="event" & estimator=="OLS log"]
grid.text(paste(
 sprintf("Matched: %s treated sales of %s parcels at %s sites; %s control sales of %s parcels at %s sites.",
  format(matched[group=="Closed",sales],big.mark=","),format(matched[group=="Closed",parcels],big.mark=","),matched[group=="Closed",sites],
  format(matched[group=="Stayed open",sales],big.mark=","),format(matched[group=="Stayed open",parcels],big.mark=","),matched[group=="Stayed open",sites]),
 "Excluded: 211 transactions lack a 2006 record; 43 lack a positive total; 496 were not single-family in 2006.",
 "The last category includes 226 land-class sales and 218 properties classified as 2-6 unit buildings in 2006.",
 sprintf("Log joint pre-test p: matched original %.3f; initial value by year %.3f; all premiums by year %.3f.",
  pre[comparison=="Matched: existing model",pretrend_p],pre[comparison=="Matched: initial value by year",pretrend_p],
  pre[comparison=="Matched: all premiums by year",pretrend_p]),
 "A non-rejecting joint test does not establish parallel trends. The adjusted 2010 log interval still excludes zero.",
 "Source: Cook County Assessor - Assessed Values (uzyt-m557), tax year 2006, mailed_tot, linked by 14-digit PIN.",
 "Mailed means the initial Assessor value, before appeals. Values remain assessed dollars; no market-value conversion.",
 paste("Retrieved",substr(a$source_info$retrieved_utc,1,10),"with original JSON responses, metadata, exact queries and checksums preserved."),
 "This is a robustness check using a fixed historical covariate. It does not identify the cause of the pre-closure divergence.",
 sep="\n\n"),x=.05,y=.50,just=c("left","top"),gp=gpar(fontsize=11))
dev.off()
ggsave("../output/assessment_events.png",main,width=12,height=10,dpi=180,bg="white")
ggsave("../output/assessment_pooled.png",pooled,width=14,height=7.5,dpi=180,bg="white")
