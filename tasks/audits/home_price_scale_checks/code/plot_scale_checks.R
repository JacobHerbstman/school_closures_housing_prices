# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_scale_checks/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
a <- readRDS("../output/scale_checks.rds")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),legend.position="bottom",legend.title=element_blank(),strip.text=element_text(face="bold"),plot.title=element_text(face="bold",size=19),plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,20,18,20)))
colors <- c("OLS log"="#176D8A","PPML"="#AF493D","Observed"="#23343C","Log predictions"="#176D8A","Log predictions without treatment-year terms"="#AF493D")
events <- a$coefficients[design=="event" & estimator!="OLS dollars"]
events <- rbind(events,unique(events[,.(controls,estimator)])[,`:=`(sale_year=2012,estimate=0,conf_low=0,conf_high=0)],fill=TRUE)
events[,c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),.SDcols=c("estimate","conf_low","conf_high")]
events[,controls:=factor(controls,levels=c("without","with"),labels=c("Without property controls","With property controls"))]
setorder(events,controls,estimator,sale_year)
ppml <- ggplot(events,aes(sale_year,estimate,color=estimator,shape=estimator,group=estimator))+
 geom_hline(yintercept=0,color="gray60",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
 geom_errorbar(aes(ymin=conf_low,ymax=conf_high),position=position_dodge(.25),width=.12,alpha=.65)+
 geom_line(linewidth=.8)+geom_point(position=position_dodge(.25),size=2)+facet_wrap(~controls,nrow=1)+
 scale_color_manual(values=colors)+scale_x_continuous(breaks=seq(2008,2018,2))+
 labs(title="PPML versus OLS on log prices",subtitle="Single-family houses and townhouses | Half mile | 11,202 sales at 68 sites",
 x="Sale year",y="100 x [exp(coefficient) - 1]",
 caption="Same transactions, property controls, school-site and year fixed effects; 2012 reference. Site-clustered 95% intervals.\nPPML models the conditional mean dollar price. OLS models the conditional mean log price; the percentage scales have different meanings.\nAll prices are in 2022 dollars. These checks do not resolve pre-trend or anticipation concerns.")
gaps <- a$gaps[series %in% c("observed","predicted","predicted_no_event")]
gaps[,series:=factor(series,levels=c("observed","predicted","predicted_no_event"),labels=c("Observed","Log predictions","Log predictions without treatment-year terms"))]
gaps[,controls:=factor(controls,levels=c("without","with"),labels=c("Without property controls","With property controls"))]
gaps <- melt(gaps,id.vars=c("controls","sale_year","series"),measure.vars=c("gap","change_from_2012"),variable.name="comparison")
gaps[,comparison:=factor(comparison,levels=c("gap","change_from_2012"),labels=c("Treated minus control mean","Change in that gap since 2012"))]
setorder(gaps,controls,comparison,series,sale_year)
raw <- ggplot(gaps,aes(sale_year,value/1000,color=series,linetype=series,group=series))+
 geom_hline(yintercept=0,color="gray65",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
 geom_line(linewidth=.85)+geom_point(size=1.6)+facet_grid(comparison~controls,scales="free_y")+
 scale_color_manual(values=colors)+scale_linetype_manual(values=c("Observed"="solid","Log predictions"="solid","Log predictions without treatment-year terms"="dashed"))+
 scale_x_continuous(breaks=seq(2008,2018,2))+labs(title="Can fitted log prices reproduce the raw dollar gaps?",
 subtitle="Annual transaction means on the same complete-characteristics sample",x="Sale year",y="Thousands of 2022 dollars",
 caption="Dollar predictions = exp(fitted log price) x the pooled mean of exp(log residual). This assumes a common smearing factor.\nThe dashed curve removes treatment-year terms but keeps site/year effects and each sale's observed characteristics.\nThese are in-sample reconstructions, with no prediction intervals. Separate pre-period group factors are saved as a sensitivity check.")
observed <- a$coefficients[design=="event" & estimator=="OLS dollars",.(controls,sale_year,estimate,conf_low,conf_high,series="Observed")]
projected <- a$projections[prediction %in% c("predicted","predicted_no_event"),.(controls,sale_year,estimate,series=ifelse(prediction=="predicted","Log predictions","Log predictions without treatment-year terms"))]
d <- rbind(observed,projected,fill=TRUE)
d <- rbind(d,unique(d[,.(controls,series)])[,`:=`(sale_year=2012,estimate=0,conf_low=0,conf_high=0)],fill=TRUE)
d[,controls:=factor(controls,levels=c("without","with"),labels=c("Without property controls","With property controls"))]
setorder(d,controls,series,sale_year)
levels <- ggplot(d,aes(sale_year,estimate/1000,color=series,linetype=series,group=series))+
 geom_hline(yintercept=0,color="gray65",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
 geom_errorbar(data=d[series=="Observed"],aes(ymin=conf_low/1000,ymax=conf_high/1000),width=.1,alpha=.3)+
 geom_line(linewidth=.9)+geom_point(size=1.8)+facet_wrap(~controls,nrow=1)+scale_color_manual(values=colors)+
 scale_linetype_manual(values=c("Observed"="solid","Log predictions"="solid","Log predictions without treatment-year terms"="dashed"))+
 scale_x_continuous(breaks=seq(2008,2018,2))+labs(title="Can log-model predictions reproduce the levels event study?",
 subtitle="Apply the original dollar OLS specification to observed and predicted prices",x="Sale year",y="Treated-control difference relative to 2012 (thousands of dollars)",
 caption="Blue and dashed red curves regress the dollar predictions on the SAME regressors used for the observed levels model.\nThese are additive projections, not the log model's direct treatment effects in dollars. Original 95% intervals are shown in gray.\nA common percentage movement can create different dollar movements when baseline prices differ. Prediction curves have no uncertainty bands.")
pdf("../output/scale_checks.pdf",width=12,height=8.5,onefile=TRUE,useDingbats=FALSE)
print(ppml);print(raw);print(levels)
dev.off()
ggsave("../output/ppml_events.png",ppml,width=12,height=8.5,dpi=180,bg="white")
ggsave("../output/predicted_gaps.png",raw,width=12,height=9,dpi=180,bg="white")
ggsave("../output/predicted_levels_events.png",levels,width=12,height=8.5,dpi=180,bg="white")
