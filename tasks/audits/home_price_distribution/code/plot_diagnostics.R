# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_price_distribution/code")
library(data.table)
annual <- fread("../output/annual_prices.csv")
tails <- fread("../output/tail_contributions.csv")
composition <- fread("../output/property_composition.csv")
coefs <- fread("../output/site_omission_coefficients.csv")
models <- fread("../output/site_omission_models.csv")
blue <- "#247BA0"
red <- "#BC4749"
groups <- c("Listed schools remaining open", "Listed schools that closed")
years <- 2008:2018
png("../output/annual_price_distribution.png", width = 2000, height = 1500, res = 180)
par(mfrow = c(2,2), mar = c(3.5,4.5,3,1), oma = c(3,0,3,0))
for (panel in c("center", "tail")) {
  fields <- if (panel == "center") c("p10", "p25", "median_price", "mean_price", "p75") else c("mean_price", "p90", "p95", "p99")
  colors <- if (panel == "center") c("#BBBBBB", "#809BCE", "#222222", red, blue) else c(red, blue, "#6554A4", "#555555")
  labels <- if (panel == "center") c("10th percentile", "25th percentile", "Median", "Mean", "75th percentile") else c("Mean", "90th percentile", "95th percentile", "99th percentile")
  for (group in 0:1) {
    d <- annual[treated == group]
    plot(range(years), c(0, max(unlist(annual[, ..fields])) / 1000 * 1.12), type = "n", xlab = "", ylab = "Price (thousands of 2022 dollars)", main = groups[group+1], xaxt = "n")
    axis(1, at = seq(2008,2018,2)); abline(v = 2013, col = "#CCCCCC", lty = 3)
    for (j in seq_along(fields)) lines(d$sale_year, d[[fields[j]]] / 1000, col = colors[j], lwd = 2, lty = if (fields[j] == "mean_price") 2 else 1)
    legend("topleft", labels, col = colors, lty = ifelse(fields == "mean_price", 2, 1), lwd = 2, bty = "n", cex = .75)
  }
}
mtext("Annual transaction-price distributions", outer = TRUE, side = 3, line = .6, font = 2, cex = 1.2)
mtext("Quarter-mile sample; equal weight per sale. Vertical line: 2013 closure year. Common scales within each row.", outer = TRUE, side = 1, line = 1, cex = .78)
dev.off()

png("../output/expensive_sales_contribution.png", width = 2000, height = 1450, res = 180)
par(mfrow = c(2,2), mar = c(3.5,4.5,3,1), oma = c(3,0,3,0))
for (group in 0:1) {
  d <- tails[treated == group & tail_fraction == .05]
  plot(range(years), c(0,max(annual$mean_price)/1000*1.15), type = "n", xlab = "", ylab = "Contribution to mean ($1,000)", main = groups[group+1], xaxt = "n")
  axis(1, at = seq(2008,2018,2)); abline(v = 2013, col = "#CCCCCC", lty = 3)
  polygon(c(years,rev(years)), c(rep(0,11),rev(d$rest_contribution_to_mean/1000)), border = NA, col = "#C9DFEA")
  polygon(c(years,rev(years)), c(d$rest_contribution_to_mean/1000, rev((d$rest_contribution_to_mean+d$tail_contribution_to_mean)/1000)), border = NA, col = "#EDB7B8")
  lines(years,(d$rest_contribution_to_mean+d$tail_contribution_to_mean)/1000,lwd=2)
  legend("topleft", c("Most expensive 5%", "Remaining sales", "Overall mean"), fill = c("#EDB7B8", "#C9DFEA", NA), border = NA, lty = c(NA,NA,1), bty = "n", cex = .8)
}
for (group in 0:1) {
  plot(range(years),c(0, max(tails$value_share)*115),type="n", xlab="",ylab="Share of total sale value (%)", main=groups[group+1],xaxt="n")
  axis(1,at=seq(2008,2018,2)); abline(v=2013,col="#CCCCCC",lty=3)
  for (j in 1:3) { d <- tails[treated==group & tail_fraction==c(.01,.05,.10)[j]]; lines(d$sale_year,100*d$value_share,col=c("#6554A4",red,blue)[j],lwd=2) }
  legend("topleft",c("Most expensive 1%","Most expensive 5%","Most expensive 10%"),col=c("#6554A4",red,blue),lwd=2,bty="n",cex=.8)
}
mtext("How much do expensive sales contribute to dollar means?",outer=TRUE,side=3,line=.6,font=2,cex=1.15)
mtext("Rankings are within treatment group and year; ties at the cutoff excluded from the upper tail. No sales removed.",outer=TRUE,side=1,line=1,cex=.76)
dev.off()

png("../output/property_composition.png",width=2000,height=2000,res=180)
par(mfrow=c(3,2),mar=c(3,4.5,3,1),oma=c(3,0,3,0))
for (panel in c("share","types","fixed")) for (group in 0:1) {
  d <- composition[treated==group & property_type=="Apartments (2-6 units)"]
  a <- annual[treated==group]
  ylim <- if(panel=="share") c(0,100) else c(0,max(composition$mean_price)/1000*1.2)
  plot(range(years),ylim,type="n",xlab="",ylab=if(panel=="share") "Apartment buildings (% of sales)" else "Mean price (2022 $1,000)",main=groups[group+1],xaxt="n")
  axis(1,at=seq(2008,2018,2)); abline(v=2013,col="#CCCCCC",lty=3)
  if(panel=="share") {
    lines(years,d$sales_share*100,col=blue,lwd=2); lines(years,d$top5_sales_share*100,col=red,lwd=2,lty=2)
    legend("topleft",c("All sales","Most expensive 5%"),col=c(blue,red),lty=c(1,2),lwd=2,bty="n",cex=.8)
  } else if(panel=="types") {
    h <- composition[treated==group & property_type=="Houses/townhouses"]
    lines(years,d$mean_price/1000,col=blue,lwd=2); lines(years,h$mean_price/1000,col=red,lwd=2,lty=2)
    legend("topleft",c("Apartments (2-6 units)","Houses/townhouses"),col=c(blue,red),lty=c(1,2),lwd=2,bty="n",cex=.8)
  } else {
    lines(years,a$mean_price/1000,col="black",lwd=2); lines(years,a$fixed_type_share_mean/1000,col=blue,lwd=2,lty=2)
    legend("topleft",c("Observed mean","Fixed pre-closure type shares"),col=c("black",blue),lty=c(1,2),lwd=2,bty="n",cex=.8)
  }
}
mtext("Changes in the properties sold",outer=TRUE,side=3,line=.6,font=2,cex=1.2)
mtext("Fixed mix uses each group's pooled 2008-2012 house/apartment shares; other property characteristics can still change.",outer=TRUE,side=1,line=1,cex=.77)
dev.off()

influence <- merge(coefs,models,by=c("model","omitted_site_id"))
png("../output/site_omission_did.png",width=2400,height=1900,res=180)
par(mfrow=c(2,2),mar=c(4,12,3,1),oma=c(3,0,3,0))
for(hedonic in c(FALSE,TRUE)) for(outcome in c("log","dollars")) {
  model_name <- paste0("did",if(hedonic) "_hedonic" else "","_",outcome)
  d <- influence[model==model_name & omitted_site_id!=0][order(-abs(change_from_full))][1:8]
  full <- influence[model==model_name & omitted_site_id==0]
  scale <- if(outcome=="dollars") 1000 else 1
  labels <- gsub(" Elementary School", "", d$omitted_school,fixed=TRUE)
  labels <- gsub("Alexander von Humboldt / Ana Roque de Duprey", "Humboldt / Duprey", labels, fixed=TRUE)
  labels <- gsub(" Elementary Specialty School| Special Education Center| Math & Science Academy ES", "", labels)
  labels <- paste0(labels,ifelse(d$omitted_treated==1," (T)"," (C)"))
  labels <- c("Full sample",labels)
  d <- rbindlist(list(full,d))
  plot(range(c(d$conf_low,d$conf_high))/scale,c(.5,9.5),type="n",xlab=if(outcome=="log") "Log-price coefficient" else "Price coefficient (2022 $1,000)",ylab="",yaxt="n",main=paste(if(hedonic) "With property controls" else "Site and year fixed effects",if(outcome=="log") "| Logs" else "| Dollars"))
  axis(2,at=9:1,labels=labels,las=1,cex.axis=.8,tick=FALSE)
  abline(v=0,col="#BBBBBB"); abline(v=full$estimate/scale,lty=2,col="#777777")
  colors <- c("black",ifelse(d$omitted_treated[-1]==1,red,blue))
  segments(d$conf_low/scale,9:1,d$conf_high/scale,9:1,col=colors)
  points(d$estimate/scale,9:1,col=colors,pch=19,cex=1.1)
}
mtext("Omit one school site: eight largest coefficient changes in each specification",outer=TRUE,side=3,line=.6,font=2,cex=1.15)
mtext("All 77 omissions estimated. Bars: site-clustered 95% intervals. T = closed; C = remained open. DiD excludes 2013.",outer=TRUE,side=1,line=1,cex=.8)
dev.off()

png("../output/site_omission_events.png",width=2000,height=1500,res=180)
par(mfrow=c(2,2),mar=c(3.5,4.5,3,1),oma=c(3,0,3,0))
for(hedonic in c(FALSE,TRUE)) for(outcome in c("log","dollars")) {
  model_name <- paste0("event",if(hedonic) "_hedonic" else "","_",outcome)
  d <- coefs[model==model_name]
  d <- rbindlist(list(d,data.table(omitted_site_id=unique(d$omitted_site_id),sale_year=2012,estimate=0,conf_low=0,conf_high=0)),fill=TRUE)
  setorder(d,omitted_site_id,sale_year)
  full <- d[omitted_site_id==0]
  bounds <- d[omitted_site_id!=0,.(low=min(estimate),high=max(estimate)),by=sale_year][order(sale_year)]
  scale <- if(outcome=="dollars") 1000 else 1
  plot(range(years),range(c(bounds$low,bounds$high,full$conf_low,full$conf_high))/scale,type="n",xlab="",ylab=if(outcome=="log") "Log-price coefficient" else "Price coefficient (2022 $1,000)",main=paste(if(hedonic) "With property controls" else "Site and year fixed effects",if(outcome=="log") "| Logs" else "| Dollars"),xaxt="n")
  axis(1,at=seq(2008,2018,2)); abline(h=0,col="#BBBBBB"); abline(v=2013,col="#CCCCCC",lty=3)
  polygon(c(years,rev(years)),c(bounds$low,rev(bounds$high))/scale,col="#D5E5ED",border=NA)
  segments(years,full$conf_low/scale,years,full$conf_high/scale,col="#777777")
  lines(years,full$estimate/scale,col=blue,lwd=2); points(years,full$estimate/scale,col=blue,pch=19,cex=.6)
  legend("topleft",c("Full-sample estimate","Range across 77 omissions","Full-sample 95% interval"),col=c(blue,"#D5E5ED","#777777"),lwd=c(2,8,1),bty="n",cex=.7)
}
mtext("Annual event studies after omitting each school site",outer=TRUE,side=3,line=.6,font=2,cex=1.2)
mtext("2012 reference. Shading is the range of coefficient estimates across omissions, not a confidence interval.",outer=TRUE,side=1,line=1,cex=.8)
dev.off()
