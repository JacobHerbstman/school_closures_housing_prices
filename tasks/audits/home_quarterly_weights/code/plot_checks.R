# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_quarterly_weights/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})
a <- readRDS("../output/quarterly_weights.rds")
theme_set(theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),
 legend.position="bottom",legend.title=element_blank(),strip.text=element_text(face="bold"),
 plot.title=element_text(face="bold",size=18),plot.caption=element_text(hjust=0,size=9),plot.margin=margin(15,20,15,20)))
comparison_colors <- c("Transactions"="#176D8A","Equal sites"="#BD6D27","Drop top three"="#53855A")
group_colors <- c("Closed"="#AF493D","Stayed open"="#176D8A")
events <- copy(a$coefficients[design=="event"])
reference <- unique(events[,.(frequency,comparison,controls,estimator)])
reference[,`:=`(period=ifelse(frequency=="Annual",2012L,19L),estimate=0,conf_low=0,conf_high=0)]
events <- rbind(events,reference,fill=TRUE)
events[,time:=ifelse(frequency=="Annual",period,2008+(period-.5)/4)]
# Coefficients from the two multiplicative models are shown as exp(beta)-1.
# OLS logs and PPML target different conditional moments despite this common scale.
events[estimator!="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),.SDcols=c("estimate","conf_low","conf_high")]
events[estimator=="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)x/1000),.SDcols=c("estimate","conf_low","conf_high")]
events[,estimator:=factor(estimator,levels=c("OLS dollars","OLS log","PPML"),labels=c("OLS dollars ($1,000s)","OLS logs (%)","PPML (%)"))]
events[,comparison:=factor(comparison,levels=c("Transactions","Equal sites","Drop top three"))]
events[,controls:=factor(controls,levels=c("without","with"),labels=c("Without property controls","With property controls"))]
setorder(events,frequency,comparison,controls,estimator,period)
quarter <- ggplot(events[frequency=="Quarterly" & controls=="With property controls" & period %between% c(13,32)],
 aes(time,estimate,color=comparison))+
 annotate("rect",xmin=2012.75,xmax=2013.5,ymin=-Inf,ymax=Inf,fill="gray75",alpha=.23)+
 geom_hline(yintercept=0,color="gray60",linetype=2)+geom_vline(xintercept=2013.5,color="gray45",linetype=3)+
 geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.06,alpha=.5)+geom_line(linewidth=.7)+geom_point(size=1.5)+
 facet_grid(estimator~comparison,scales="free_y")+scale_color_manual(values=comparison_colors,guide="none")+
 scale_x_continuous(breaks=(2011:2015)+.125,labels=paste0(2011:2015," Q1"))+
 labs(title="Quarterly price comparisons around the closure decisions",subtitle="Half-mile single-family sample | With property controls | Reference: 2012 Q3",
 x="Sale quarter (one point each quarter)",y="Treated-control coefficient relative to 2012 Q3",
 caption="Shading spans 2012 Q4 (December utilization list), 2013 Q1 (February candidates and March proposals), and 2013 Q2 (May vote and June school-year end).\nThe dotted line starts 2013 Q3, the first full quarter after June. Quarters cannot separate February from March or May from June.\nSchool-site and calendar-quarter fixed effects; site-clustered pointwise 95% intervals. Each model uses all 2008-2018 sales; only the display is zoomed.\nEqual sites assigns total weight one to each observed site-quarter. Drop top three removes Buckingham, Trumbull and Key; all control sites remain.")
quarter_without <- quarter %+% events[frequency=="Quarterly" & controls=="Without property controls" & period %between% c(13,32)]
quarter_without <- quarter_without+labs(subtitle="Half-mile single-family sample | Without property controls | Reference: 2012 Q3")
quarter_full <- quarter %+% events[frequency=="Quarterly" & controls=="With property controls"]
quarter_full <- quarter_full+scale_x_continuous(breaks=seq(2008,2018,2)+.125,labels=paste0(seq(2008,2018,2)," Q1"))+
 labs(title="The full quarterly event studies",subtitle="2008-2018 | With property controls | Reference: 2012 Q3",
 caption="Shading spans 2012 Q4 through 2013 Q2; the dotted line begins the first full quarter after June. All 44 quarters are shown.\nSchool-site and calendar-quarter fixed effects; site-clustered pointwise 95% intervals. Joint pre-period tests reject flatness in all nine panels.\nEqual sites assigns total weight one to each observed site-quarter. Drop top three removes Buckingham, Trumbull and Key.\nNeither these comparisons nor the quarterly resolution distinguish announcement effects from physical-building effects.")
annual <- ggplot(events[frequency=="Annual"],aes(time,estimate,color=comparison,fill=comparison,group=comparison))+
 geom_hline(yintercept=0,color="gray60",linetype=2)+geom_vline(xintercept=2013,color="gray60",linetype=3)+
 geom_ribbon(aes(ymin=conf_low,ymax=conf_high),alpha=.09,color=NA)+geom_line(linewidth=.8)+geom_point(size=1.5)+
 facet_grid(estimator~controls,scales="free_y")+scale_color_manual(values=comparison_colors)+scale_fill_manual(values=comparison_colors)+
 scale_x_continuous(breaks=seq(2008,2018,2))+labs(title="Changing site influence does not remove the dollar pattern",
 subtitle="Annual event studies | Same half-mile single-family sample | Reference: 2012",x="Sale year",y="Treated-control coefficient relative to 2012",
 caption="Each sale has weight one, or 1 / sales at its site in that year. Empty site-years receive no price observation.\nThe exclusion uses the three largest treated sites by 2008-2018 sales; they are also the three largest by pre-2013 sales.\nSchool-site and year fixed effects; shaded bands are site-clustered pointwise 95% intervals. All event studies retain 2013.\nOLS logs and PPML are displayed as 100 x [exp(coefficient) - 1]; their conditional-moment assumptions differ. Reweighting does not establish parallel trends.")
pooled <- copy(a$coefficients[frequency=="Annual" & design=="did" & controls=="with"])
pooled[estimator!="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),.SDcols=c("estimate","conf_low","conf_high")]
pooled[estimator=="OLS dollars",c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)x/1000),.SDcols=c("estimate","conf_low","conf_high")]
pooled[,comparison:=factor(comparison,levels=rev(c("Transactions","Equal sites","Drop top three")))]
pooled[,estimator:=factor(estimator,levels=c("OLS dollars","OLS log","PPML"),labels=c("OLS dollars ($1,000s)","OLS logs (%)","PPML (%)"))]
did <- ggplot(pooled,aes(estimate,comparison,color=comparison))+
 geom_vline(xintercept=0,color="gray60",linetype=2)+geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation="y",width=.12)+geom_point(size=3)+
 facet_wrap(~estimator,nrow=1,scales="free_x")+scale_color_manual(values=comparison_colors,guide="none")+
 labs(title="The pooled dollar estimate gets larger in both sensitivity checks",subtitle="2014-2018 versus 2008-2012 | With property controls and school-site/year fixed effects",
 x="Estimate and site-clustered 95% interval",y=NULL,
 caption="Transactions: 10,159 sales in the pooled comparison. Drop top three: 9,452 sales; Buckingham, Trumbull and Key excluded.\nEqual sites uses 1 / site-year sales, so every observed site-year receives equal weight. Treatment definitions and price cleaning are unchanged.\nOnly this pooled summary omits 2013. Annual and quarterly event studies display all of 2013. These sensitivity estimates do not resolve selection or pre-trends.")
raw <- melt(a$raw,id.vars=c("frequency","comparison","group","period","sales","sites"),
 measure.vars=c("mean_price","mean_log_price"),variable.name="measure",value.name="value")
raw[,time:=ifelse(frequency=="Annual",period,2008+(period-.5)/4)]
raw[measure=="mean_log_price",value:=exp(value)]
raw[,`:=`(value=value/1000,comparison=factor(comparison,levels=c("Transactions","Equal sites","Drop top three")),
 measure=factor(measure,levels=c("mean_price","mean_log_price"),labels=c("Arithmetic mean price","Geometric mean price")))]
setorder(raw,frequency,comparison,measure,group,period)
raw_quarter <- ggplot(raw[frequency=="Quarterly" & period %between% c(13,32)],aes(time,value,color=group,group=group))+
 annotate("rect",xmin=2012.75,xmax=2013.5,ymin=-Inf,ymax=Inf,fill="gray75",alpha=.23)+
 geom_vline(xintercept=2013.5,color="gray50",linetype=3)+geom_line(linewidth=.85)+geom_point(size=1.6)+
 facet_grid(measure~comparison,scales="free_y")+scale_color_manual(values=group_colors)+
 scale_x_continuous(breaks=(2011:2015)+.125,labels=paste0(2011:2015," Q1"))+
 labs(title="Raw quarterly price trends under the three comparisons",subtitle="Same complete-characteristics sample used by all models; no regression adjustment",
 x="Sale quarter",y="Thousands of 2022 dollars",
 caption="Arithmetic mean averages prices. Geometric mean exponentiates the average log price; it is not the median. Weights follow the column labels.\nShading spans 2012 Q4 through 2013 Q2; the dotted line begins the first full quarter after June 2013.\nTransaction weights and equal site-quarter weights use 11,202 sales over 2008-2018. Dropping the three busiest treated sites leaves 10,433 sales.")
raw_annual <- raw_quarter %+% raw[frequency=="Annual"]
raw_annual <- raw_annual+scale_x_continuous(breaks=seq(2008,2018,2))+
 labs(title="Raw annual price trends under the three comparisons",subtitle="Site weights are recomputed within each year",x="Sale year",
 caption="Arithmetic mean averages prices. Geometric mean exponentiates average log price. Prices are in 2022 dollars.\nEqual sites gives each observed site-year total weight one. A site without sales contributes no price, so the observed site roster can change.\nAll columns use the same cleaning and school definitions; the last removes Buckingham, Trumbull and Key.")
availability <- a$support[frequency=="Quarterly" & comparison=="Transactions",.(sales=as.numeric(sum(sales)),
 active_share=100*mean(sales>0),single_sale_share=100*sum(sales==1)/sum(sales>0)),by=.(group,period)]
stopifnot(!anyDuplicated(availability[,.(group,period)]),!anyDuplicated(a$date_support[,.(group,quarter_id)]))
availability <- merge(availability,a$date_support[,.(group,period=quarter_id,refined_share=100*refined_share)],by=c("group","period"))
availability <- melt(availability,id.vars=c("group","period"),variable.name="measure",value.name="value")
availability[,`:=`(time=2008+(period-.5)/4,measure=factor(measure,
 levels=c("sales","active_share","single_sale_share","refined_share"),
 labels=c("Sales per quarter","Sites with sales (% of each group's sites)","One-sale cells (% of active site-quarters)","Sales with a refined instrument date (%)")))]
setorder(availability,measure,group,period)
coverage <- ggplot(availability[period %between% c(13,32)],aes(time,value,color=group,group=group))+
 annotate("rect",xmin=2012.75,xmax=2013.5,ymin=-Inf,ymax=Inf,fill="gray75",alpha=.23)+
 geom_line(linewidth=.85)+geom_point(size=1.8)+facet_wrap(~measure,ncol=2,scales="free_y")+scale_color_manual(values=group_colors)+
 scale_x_continuous(breaks=(2011:2015)+.125,labels=paste0(2011:2015," Q1"))+
 labs(title="Quarterly estimates have limited treated sales and changing date precision",
 subtitle="Baseline estimation sample: 22 treated sites and 46 control sites represented somewhere during 2008-2018",x="Sale quarter",y=NULL,
 caption="Equal site-quarter weighting increases the influence of cells with one sale. Empty cells are not filled in.\nBefore late 2012 most dates identify a recording month; from 2013 most are refined instrument dates. Neither field records when the price was agreed.\nThe changing date source and transaction-completion lags limit event timing; the quarter containing an announcement also contains sales predating it.")
pdf("../output/quarterly_weights.pdf",width=14,height=10,onefile=TRUE,useDingbats=FALSE)
print(did); print(annual); print(quarter); print(quarter_without); print(raw_quarter); print(raw_annual); print(coverage); print(quarter_full)
dev.off()
ggsave("../output/quarterly_events.png",quarter,width=14,height=10,dpi=180,bg="white")
ggsave("../output/annual_weights.png",annual,width=14,height=10,dpi=180,bg="white")
ggsave("../output/quarterly_raw.png",raw_quarter,width=14,height=9,dpi=180,bg="white")
