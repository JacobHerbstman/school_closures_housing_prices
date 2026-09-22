# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_data_overview/code")
suppressPackageStartupMessages({library(data.table);library(ggplot2)})
a <- readRDS("../output/late_decline.rds")
counts <- copy(a$pre_price_counts)
counts[,price_group:=factor(price_group,levels=c("Below/equal pre-period median","Above pre-period median"))]
sites <- a$pre_prices[,.(sites=.N),by=.(group,price_group)]
print(a$pre_price_definition)
print(sites)
print(counts[sale_year>=2016])
p <- ggplot(counts,aes(sale_year,sales,color=price_group,shape=price_group))+
 geom_vline(xintercept=2013,linetype=3,color="gray60")+
 geom_line(linewidth=1)+geom_point(size=2.4)+facet_wrap(~group,nrow=1,labeller=as_labeller(c("Closed"="Treated","Stayed open"="Control")))+
 scale_color_manual(values=c("Below/equal pre-period median"="#176D8A","Above pre-period median"="#AF493D"),labels=c("Below/equal pre-period median"="Below/equal median","Above pre-period median"="Above median"))+
 scale_shape_manual(values=c("Below/equal pre-period median"=16,"Above pre-period median"=17),labels=c("Below/equal pre-period median"="Below/equal median","Above pre-period median"="Above median"))+
 scale_x_continuous(breaks=2008:2018)+scale_y_continuous(limits=c(0,NA),labels=scales::label_comma())+
 labs(title="Sales in initially cheaper and more expensive school neighborhoods",
 subtitle=paste0("Quarter-mile sample; fixed groups based on each site's 2008-2012 median sale price"),
 x=NULL,y="Number of sales",color=NULL,shape=NULL,
 caption=paste0("Common cutoff: ",scales::dollar(a$pre_price_definition$cutoff,accuracy=1)," (2022 dollars), the median of pre-period site medians across treated and control sites.\nEach sale counts once. A site's category stays fixed; sales are not reclassified using their own prices.\n",a$pre_price_definition$unclassified_sales," sales lack a site pre-period price and are omitted. Dotted line marks 2013; counts are not turnover rates."))+
 theme_minimal(base_size=12)+theme(panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),legend.position="bottom",plot.title=element_text(face="bold"),plot.caption=element_text(hjust=0,size=10),plot.margin=margin(18,18,18,18),axis.text.x=element_text(angle=45,hjust=1))
ggsave("../output/sales_by_pre_price.png",p,width=12,height=6.5,dpi=180,bg="white")
ggsave("../output/sales_by_pre_price.pdf",p,width=12,height=6.5)
