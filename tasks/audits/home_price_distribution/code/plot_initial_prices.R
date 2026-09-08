# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
library(data.table)
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L)
outcome <- args[1]
# outcome <- "log"
stopifnot(outcome %in% c("dollars","log"))
scale <- if(outcome=="dollars") 1000 else 1
c <- fread("../output/initial_price_coefficients.csv")
c <- c[startsWith(model,"event") & endsWith(model,outcome) & component=="treatment"]
reference <- unique(c[,.(model,initial_price_adjusted)])
reference[,`:=`(sale_year=2012L,estimate=0,conf_low=0,conf_high=0)]
c <- rbindlist(list(c,reference),fill=TRUE)
setorder(c,model,initial_price_adjusted,sale_year)
if(outcome=="log") png("../output/initial_price_log_events.png",width=2200,height=1100,res=180) else
  png("../output/initial_price_events.png",width=2200,height=1100,res=180)
par(mfrow=c(1,2),mar=c(4,4.5,3,1),oma=c(4,0,3,0))
for(hedonic in c(FALSE,TRUE)) {
  name <- paste0("event",if(hedonic) "_hedonic" else "","_",outcome)
  plot(c(2008,2018),range(c$conf_low,c$conf_high)/scale,type="n",xaxt="n",xlab="Year",ylab=if(outcome=="log") "Log-price coefficient" else "Price coefficient (thousands of 2022 dollars)",main=if(hedonic) "With property controls" else "Site and year fixed effects")
  axis(1,at=2008:2018,cex.axis=.8);abline(h=0,col="#AAAAAA");abline(v=2013,lty=3,col="#AAAAAA")
  for(a in 0:1) {
    d <- c[model==name & initial_price_adjusted==a]
    color <- c("#247BA0","#BC4749")[a+1]
    x <- d$sale_year+c(-.07,.07)[a+1]
    segments(x,d$conf_low/scale,x,d$conf_high/scale,col=adjustcolor(color,alpha.f=.55))
    lines(x,d$estimate/scale,col=color,lwd=2,lty=a+1);points(x,d$estimate/scale,col=color,pch=c(19,17)[a+1])
  }
  legend("topleft",c("Existing model","Initial price x year added"),col=c("#247BA0","#BC4749"),lty=1:2,pch=c(19,17),lwd=2,bty="n",cex=.85)
}
mtext(if(outcome=="log") "Initial price adjustment in the log event study" else "Do initial price levels explain the dollar event study?",outer=TRUE,side=3,line=.6,font=2,cex=1.25)
mtext("Initial price: each site's pooled 2008-2012 mean. Same 10,921 sales and equal transaction weights; 2012 reference.",outer=TRUE,side=1,line=1,cex=.82)
mtext("Bars: site-clustered 95% intervals, treating the estimated initial-price covariate as fixed.",outer=TRUE,side=1,line=2.2,cex=.8)
dev.off()
