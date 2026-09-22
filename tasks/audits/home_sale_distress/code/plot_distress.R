# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sale_distress/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})
a <- readRDS("../output/distress.rds")
theme_set(theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),
 panel.grid.major.x=element_blank(),legend.position="bottom",legend.title=element_blank(),
 strip.text=element_text(face="bold"),plot.title=element_text(face="bold",size=19),
 plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,20,18,20)))
colors <- c("Closed"="#AF493D","Stayed open"="#176D8A")
d <- melt(a$annual,id.vars=c("sample","group","sale_year","sales","seller_coverage"),
 measure.vars=c("narrow_share","broad_share"),variable.name="measure",value.name="share")
d[,measure:=factor(measure,levels=c("narrow_share","broad_share"),
 labels=c("Judicial-sale / Fannie / Freddie / HUD sellers","Also including bank / mortgage-company sellers"))]
# Seller identities are especially incomplete in 2015. Break the lines there
# rather than interpreting the disappearance of recorded names as falling distress.
d <- d[sale_year!=2015]
d[,line_segment:=interaction(group,sale_year>2015)]
setorder(d,sample,measure,group,sale_year)
seller <- ggplot(d[sample=="Packet"],aes(sale_year,100*share,color=group))+
 annotate("rect",xmin=2014.7,xmax=2015.3,ymin=-Inf,ymax=Inf,fill="gray80",alpha=.5)+
 geom_vline(xintercept=2013,color="gray50",linetype=3)+
 geom_line(aes(group=line_segment),linewidth=.9)+geom_point(size=2.3)+facet_wrap(~measure,nrow=1)+
 scale_color_manual(values=colors)+scale_x_continuous(breaks=2008:2018)+
 scale_y_continuous(limits=c(0,55),breaks=seq(0,50,10),labels=function(x)paste0(x,"%"))+
 labs(title="Foreclosure-related seller proxies do not spike in treated areas in 2010",
 subtitle="Single-family houses and townhouses | Half mile | 2008-2018 | Existing price sample",
 x="Sale year",y="Share of sales with a usable seller name",
 caption="Narrow proxy: judicial-sale companies/sheriffs, Fannie Mae, Freddie Mac or HUD named as seller. The broader proxy adds banks/mortgage companies.\nNeither verifies foreclosure status; bank sellers may be trustees. No investor status is inferred. Each transaction has equal weight.\n2010: 116 treated and 749 control sales, all with seller names. The 2015 gap marks missing/UNKNOWN sellers: 37% treated and 47% control.\nThe dotted line marks 2013. Detailed deed information cannot measure the 2010 crisis exposure because it is almost entirely missing then.")
coverage <- melt(a$annual[sample=="Packet"],id.vars=c("group","sale_year"),
 measure.vars=c("seller_coverage","deed_coverage","deed_share"),variable.name="measure",value.name="share")
coverage <- coverage[measure!="deed_share" | sale_year>=2013]
coverage[,measure:=factor(measure,levels=c("seller_coverage","deed_coverage","deed_share"),
 labels=c("Seller names reported\nShare of all sales","Detailed deed reported\nShare of all sales","Foreclosure-related deeds\nShare of reported deeds; 2013 onward"))]
setorder(coverage,measure,group,sale_year)
deeds <- ggplot(coverage,aes(sale_year,100*share,color=group,group=group))+
 geom_vline(xintercept=2013,color="gray60",linetype=3)+geom_line(linewidth=.85)+geom_point(size=2)+
 facet_wrap(~measure,nrow=1,scales="free_y")+scale_color_manual(values=colors)+
 scale_x_continuous(breaks=seq(2008,2018,2))+scale_y_continuous(labels=function(x)paste0(x,"%"))+
 labs(title="Coverage limits what the deed and seller fields can tell us",
 subtitle="Same 11,206 sales as the half-mile single-family descriptive packet",x="Sale year",y=NULL,
 caption="Foreclosure-related deeds: Judicial Sale, Sheriff's Deed, Selling Officer's Deed or Deed in lieu of Foreclosure. These are not a complete REO measure.\nThe deed-share panel starts in 2013; earlier detailed deed coverage is too incomplete to compare crisis years. The public extract has no separate REO/short-sale flag.\nReported names exclude blanks and UNKNOWN placeholders. Neither missing names nor missing deeds are classified as non-distressed.")
before <- ggplot(d,aes(sale_year,100*share,color=group))+
 annotate("rect",xmin=2014.7,xmax=2015.3,ymin=-Inf,ymax=Inf,fill="gray80",alpha=.5)+
 geom_vline(xintercept=2013,color="gray50",linetype=3)+
 geom_line(aes(group=line_segment),linewidth=.85)+geom_point(size=1.8)+facet_grid(sample~measure)+
 scale_color_manual(values=colors)+scale_x_continuous(breaks=seq(2008,2018,2))+
 scale_y_continuous(limits=c(0,60),breaks=seq(0,60,15),labels=function(x)paste0(x,"%"))+
 labs(title="The 2010 comparison also holds before the price screens",
 subtitle="Same single-family definition and half-mile geography; transaction weights",x="Sale year",y="Share of transfers with a usable seller name",
 caption="Before price screens: 15,420 single-family, single-card transfers, including low-price and otherwise excluded transactions. Packet: 11,206 sales.\nBoth retain the same school groups and exclude overlap, welcoming-school and other-candidate exposure. This does not restore multi-parcel or condominium transfers.\nProxies use identical seller-name rules in both samples; neither is a verified distress classification. The 2015 gap marks incomplete seller reporting.")
pdf("../output/distress.pdf",width=13,height=8,onefile=TRUE,useDingbats=FALSE)
print(seller); print(deeds); print(before)
dev.off()
ggsave("../output/seller_proxies.png",seller,width=13,height=8,dpi=180,bg="white")
ggsave("../output/coverage_and_deeds.png",deeds,width=13,height=8,dpi=180,bg="white")
ggsave("../output/before_price_screens.png",before,width=13,height=8,dpi=180,bg="white")
