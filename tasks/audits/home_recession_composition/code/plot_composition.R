# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_recession_composition/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(grid)})
a <- readRDS("../output/composition.rds")
m <- readRDS("../output/model_checks.rds")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),
 legend.position="bottom",legend.title=element_blank(),strip.text=element_text(face="bold"),
 plot.title=element_text(face="bold",size=19),plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,22,18,22)))
group_colors <- c("Closed"="#B34F36","Stayed open"="#287C8E","Chicago total"="#8A8F93")
mix_colors <- c("All matched sales"="#9A9FA4","Common sites: transaction weights"="#B34F36",
 "Common sites: fixed 2008-11 site shares"="#24877C")
median_plot <- ggplot(a$fixed_mix,aes(sale_year,median_initial/1000,color=series))+
 geom_line(linewidth=1)+geom_point(size=2.5)+facet_wrap(~group,ncol=1)+
 scale_color_manual(values=mix_colors)+scale_x_continuous(breaks=2008:2013)+
 labs(title="The 2012 median spike largely reflects which neighborhoods sold",
 subtitle="Median 2006 assessment of homes sold each year | Single-family homes and townhouses within half a mile",
 x="Sale year",y="2006 assessed value, thousands of dollars",
 caption="Red and green use exactly the same sales at 14 treated and 34 control sites with sales in every year from 2008 to 2013.\nGreen holds each site's share within its group at its pooled 2008-2011 share. This is a composition diagnostic, not the main weighting rule.\nTreated common-site medians: $16,417 to $29,043 with transaction weights; $16,121 to $16,371 with fixed site shares. Gray includes other sites.")

top_sites <- a$decomposition[group=="Closed"][order(-between_sites)][1:5,school_site_id]
site_mix <- copy(a$site_year[group=="Closed" & sale_year<=2013])
site_mix[,site_label:=fcase(grepl("Trumbull",school_names),"Trumbull",grepl("William H King",school_names),"King",
 grepl("Peabody",school_names),"Peabody",grepl("Duprey",school_names),"Duprey / Humboldt",
 grepl("Near North",school_names),"Near North",default="Other treated sites")]
stopifnot(setequal(site_mix[site_label!="Other treated sites",school_site_id],top_sites))
site_mix <- site_mix[,.(sales=sum(sales)),by=.(sale_year,site_label)]
site_mix[,share:=sales/sum(sales),by=sale_year]
site_mix[,site_label:=factor(site_label,levels=c("Trumbull","King","Peabody","Duprey / Humboldt","Near North","Other treated sites"))]
sites_plot <- ggplot(site_mix,aes(sale_year,100*share,fill=site_label))+
 geom_col(width=.7)+scale_x_continuous(breaks=2008:2013)+
 scale_fill_manual(values=c("#67509B","#287C8E","#C48732","#A04F62","#548E68","#D1D5D8"))+
 labs(title="Five neighborhoods account for much more of the 2012 treated sales",
 subtitle="Their combined share rises from 28 of 99 sales in 2011 to 66 of 134 in 2012",
 x="Sale year",y="Share of treated sales (%)",
 caption="These are transactions with usable 2006 assessments. The five sites make the largest positive contributions to the 2011-2012 mean shift.\nOn common sites, changing neighborhood shares explains 75.5% of the mean assessment increase; changing houses within sites explains 24.5%.\nThe middle 2012 assessments are $24,040 and $28,650, averaging $26,345. Counting each parcel once instead gives $20,880.\nFive parcels sold twice, with different deed numbers, dates and prices. Four have assessments above $25,000; these repeated transactions amplify the median jump.")

evidence <- rbind(a$foreclosure_exposure[sale_year<=2013,.(group,sale_year,value=filings_per_100,indicator="Foreclosure filings per 100 residential parcels")],
 a$annual[sale_year<=2013,.(group,sale_year,value=100*broad_seller_share,indicator="Bank / lender / judicial / GSE seller names (%)")],
 a$annual[sale_year<=2013,.(group,sale_year,value=100*narrow_seller_share,indicator="Judicial / GSE / HUD seller names (%)")],
 a$annual[sale_year<=2013,.(group,sale_year,value=100*under_50k_share,indicator="Sales below $50,000 in 2022 dollars (%)")])
evidence[,indicator:=factor(indicator,levels=unique(indicator))]
evidence_plot <- ggplot(evidence,aes(sale_year,value,color=group))+
 geom_line(linewidth=.9)+geom_point(size=2)+facet_wrap(~indicator,ncol=2,scales="free")+
 scale_color_manual(values=group_colors)+scale_x_continuous(breaks=c(2005,2008,2010,2012,2013))+
 labs(title="Distress is evident in both groups; the controls often show more",
 subtitle="Independent neighborhood foreclosure filings and indicators from our unchanged 11,202-sale sample",
 x="Year",y=NULL,caption="Filings: DePaul IHS community-area rates for all residential parcels, weighted by fixed 2008-2011 sale-location shares.\nThese area averages are not foreclosure rates inside our half-mile circles. Gray is the citywide rate. Historical published rates are rounded to one decimal.\nSeller-name shares use known names and are proxies, not verified distress. Low sale prices are not necessarily distressed transactions.")

characteristics <- melt(a$annual[sale_year<=2013],id.vars=c("group","sale_year"),
 measure.vars=c("median_sqft","median_age","townhouse_share","organization_buyer_share"),variable.name="indicator",value.name="value")
characteristics[indicator %in% c("townhouse_share","organization_buyer_share"),value:=value*100]
characteristics[,indicator:=factor(indicator,levels=c("median_sqft","median_age","townhouse_share","organization_buyer_share"),
 labels=c("Median building area (square feet)","Median building age (years)","Townhouse class share (%)","Organization-name buyers (%)"))]
characteristics_plot <- ggplot(characteristics,aes(sale_year,value,color=group))+
 geom_line(linewidth=.9)+geom_point(size=2)+facet_wrap(~indicator,ncol=2,scales="free_y")+
 scale_color_manual(values=group_colors)+scale_x_continuous(breaks=2008:2013)+
 labs(title="Other characteristics of the homes sold change as well",
 subtitle="The same 2008-2013 transactions within the full estimation sample",
 x="Sale year",y=NULL,caption="Townhouse means assessor class 295. Building characteristics are recorded for the sale year.\nOrganization-name buyers have an explicit corporate suffix (for example LLC or INC), among buyers with known names.\nThis is not a verified investor share. Pre-2013 buyer-name coverage exceeds 99% in both groups.")

event_data <- copy(m$events[comparison=="Existing model"])
event_data[,reference_label:=factor(reference,levels=c(2012,2008),labels=c("Reference year: 2012","Reference year: 2008"))]
event_data[,c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),.SDcols=c("estimate","conf_low","conf_high")]
reference_plot <- ggplot(event_data,aes(sale_year,estimate))+
 geom_hline(yintercept=0,color="gray65",linetype=2)+geom_vline(xintercept=2013,color="gray70",linetype=3)+
 geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.12,color="#52616B")+
 geom_line(linewidth=.9,color="#52616B")+geom_point(size=2,color="#52616B")+
 facet_wrap(~reference_label,ncol=1)+scale_x_continuous(breaks=2008:2018)+
 labs(title="The pre-closure dip remains with a 2008 reference",
 subtitle="Same log model, same fitted prices, same 11,202 sales | Only the reference changes",
 x="Sale year",y="Treated-control log-price contrast, converted to percent",
 caption="The relative 2008-2010 decline is 18.8% (95% interval: -34.9% to +1.3%). The 2010-2012 rebound is 24.9% (+8.2% to +44.0%).\nRebasing does not remove the time pattern or change the joint pre-period equality test (p=0.031).\nActual removal of 2012 leaves a similar 2008-2010 decline of 18.7%; this is a separate sample check, not a change in reference alone.")

contrast_data <- copy(m$contrasts[from_year==2008 | from_year==2010])
contrast_data[,c("estimate","conf_low","conf_high"):=lapply(.SD,function(x)100*expm1(x)),.SDcols=c("estimate","conf_low","conf_high")]
contrast_data[,period:=fifelse(from_year==2008,"2010 relative to 2008","2012 relative to 2010")]
comparison_order <- c("Existing model","Initial value by year","Seller types by year","Known non-bank sellers","2012 omitted",
 "Common sites: transaction weights","Common sites: fixed site shares")
contrast_data[,comparison:=factor(comparison,levels=rev(comparison_order))]
checks_plot <- ggplot(contrast_data,aes(estimate,comparison))+
 geom_vline(xintercept=0,color="gray65",linetype=2)+
 geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation="y",width=.15,color="#52616B")+
 geom_point(size=2.8,color="#B34F36")+facet_wrap(~period,nrow=1)+
 labs(title="Composition checks leave substantial pre-closure price movement",
 subtitle="Log-price contrasts, converted to percent | School-site-clustered 95% intervals",
 x="Percent",y=NULL,caption="Seller controls allow annual differences across other known, bank/lender, judicial/GSE/HUD and unknown seller categories.\nThe non-bank restriction removes broad seller matches and unknown names; initial-value controls use matched assessments.\nThe last two rows use exactly 4,919 sales at 48 common sites in 2008-2013. Other models extend through 2018. No 2012-2010 contrast exists when 2012 is omitted.")

pdf("../output/recession_composition.pdf",width=13,height=9.5,onefile=TRUE,useDingbats=FALSE)
print(median_plot);print(sites_plot);print(evidence_plot);print(characteristics_plot);print(reference_plot);print(checks_plot)
grid.newpage()
grid.text("What these checks establish",x=.05,y=.94,just="left",gp=gpar(fontsize=21,fontface="bold"))
grid.text(paste(
 "The median spike has a concrete composition explanation.",
 "More 2012 treated transactions occurred in neighborhoods with higher 2006 assessments. Fixing site shares nearly removes the spike.",
 "It is not an appreciation measure: each parcel's assessment is held at its own 2006 value.",
 "Five parcels sell twice in 2012. Counting parcels once lowers the median to $20,880; the individual sales have distinct deeds, dates and prices.",
 "The foreclosure evidence does not show greater average exposure in treated areas.",
 "In 2008, area filings average 3.85 per 100 parcels for treated locations versus 4.76 for controls; in 2010, 3.44 versus 4.01.",
 "Both groups exceed the citywide 2010 rate of 3.0. These are broad area exposures, not parcel-level foreclosure histories.",
 "The adjusted pre-period gap survives single-school omissions and seller-proxy adjustments.",
 sprintf("Leaving out each treated site gives 2010-versus-2012 estimates between %.1f%% and %.1f%%; each control omission gives %.1f%% to %.1f%%.",
  min(100*expm1(m$omissions[group=="Closed",estimate])),max(100*expm1(m$omissions[group=="Closed",estimate])),
  min(100*expm1(m$omissions[group=="Stayed open",estimate])),max(100*expm1(m$omissions[group=="Stayed open",estimate]))),
 "Seller-type controls and removing bank-related sellers leave substantial negative 2010 contrasts.",
 "Changing the reference year leaves the pre-closure dip in place.",
 "The original 2008-2010 decline is imprecise; the 2010-2012 relative rebound is more clearly estimated.",
 "Short pre-closure repeat histories are selective: only 11 treated pairs end in 2010, and 21 in 2011. Many have very large gains.",
 "They do not provide a reliable stand-alone measure of how all nearby homes fared during the crash.",
 "Sources and reproduction",
 "Run Make in tasks/audits/home_recession_composition/code. Original IHS HTML and City of Chicago boundaries are frozen locally.",
 "IHS: housingstudies.org/data-portal/browse/?indicator=foreclosures-100-residential-parcel. Boundaries: Chicago dataset igwz-8jzy.",
 "Saved data contain all joins, school contributions, weights, annual indicators, model contrasts and every single-site omission.",
 sep="\n\n"),x=.05,y=.87,just=c("left","top"),gp=gpar(fontsize=11))
dev.off()
ggsave("../output/median_spike.png",median_plot,width=12,height=9,dpi=180,bg="white")
ggsave("../output/recession_evidence.png",evidence_plot,width=13,height=9,dpi=180,bg="white")
ggsave("../output/reference_years.png",reference_plot,width=12,height=9,dpi=180,bg="white")
