# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sample_summary/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

summary <- readRDS("../output/sample_summary.rds")
series <- summary$series
site_prices <- summary$site_prices
colors <- c("Closed" = "#AF493D", "Stayed open" = "#1F6FAE")
theme_set(theme_minimal(base_size = 12) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E6E8E9", linewidth = 0.3),
  legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold"),
  plot.title = element_text(face = "bold"), plot.caption = element_text(color = "#5B666B", hjust = 0)))

# 2013 is the announcement (March 21) and closure (end of June) year: shaded
# as the whole year annually and as its first two quarters quarterly.
plot_series <- function(data, y, title, y_label, caption, frequency) {
  band <- if (frequency == "annual") c(2012.5, 2013.5) else c(2013, 2013.5)
  ggplot(data, aes(period_start, .data[[y]], color = group)) +
    annotate("rect", xmin = band[1], xmax = band[2], ymin = -Inf, ymax = Inf, fill = "#EEF0F1") +
    geom_line(linewidth = if (frequency == "annual") 0.8 else 0.5) +
    geom_point(size = if (frequency == "annual") 1.8 else 1) +
    facet_wrap(~sample, scales = "free_y") +
    scale_color_manual(values = colors) +
    scale_x_continuous(breaks = seq(2008, 2018, 2)) +
    labs(title = title, x = NULL, y = y_label, caption = caption)
}
dollars <- scales::label_dollar(scale = 1e-3, suffix = "k")
annual <- series[frequency == "annual"]
quarterly <- series[frequency == "quarterly"]
flag_note <- "Flagged: REO resales, resales within 365 days, identical buyer/seller names, prices outside the within-year 1st-99th percentiles."
sample_note <- paste("Sales within the radius of a closed (stayed-open) site and not the other group, excluding sales near welcoming schools,",
                     "other candidates, and vacated welcoming buildings. 2022 dollars.", sep = "\n")

pages <- list(
  plot_series(annual[version == "All clean sales"], "median_real_price", "Median sale price by year, all clean sales",
              "Median price", sample_note, "annual") + scale_y_continuous(labels = dollars),
  plot_series(annual[version == "Excluding flagged sales"], "median_real_price", "Median sale price by year, excluding flagged sales",
              "Median price", paste(sample_note, flag_note, sep = "\n"), "annual") + scale_y_continuous(labels = dollars),
  plot_series(annual[version == "All clean sales"], "mean_real_price", "Mean sale price by year, all clean sales",
              "Mean price", sample_note, "annual") + scale_y_continuous(labels = dollars),
  plot_series(annual[version == "All clean sales"], "sales", "Sales per year, all clean sales",
              "Sales", paste(sample_note, "Counts are not turnover rates: there is no housing-stock denominator.", sep = "\n"), "annual"),
  plot_series(annual[version == "All clean sales"], "share_reo", "Share of sales that are REO resales, by year",
              "REO share", sample_note, "annual") + scale_y_continuous(labels = scales::label_percent()),
  plot_series(quarterly[version == "All clean sales"], "median_real_price", "Median sale price by quarter, all clean sales",
              "Median price", paste(sample_note, "Shaded: 2013 Q1-Q2 (proposal March 21, vote May 22, closures end of June).", sep = "\n"),
              "quarterly") + scale_y_continuous(labels = dollars),
  plot_series(quarterly[version == "Excluding flagged sales"], "median_real_price", "Median sale price by quarter, excluding flagged sales",
              "Median price", paste(sample_note, flag_note, sep = "\n"), "quarterly") + scale_y_continuous(labels = dollars),
  plot_series(quarterly[version == "All clean sales"], "sales", "Sales per quarter, all clean sales",
              "Sales", sample_note, "quarterly")
)
# Each site's median before (2008-2012) and after (2014-2018), quarter-mile all-property sample.
sites <- dcast(site_prices[sample == "All property, 0.25 mile"], group + school_site_id + school_names ~ period,
               value.var = c("median_real_price", "sales"))
sites <- sites[!is.na(`median_real_price_2008-2012`) & !is.na(`median_real_price_2014-2018`)]
sites[, school_names := factor(school_names, levels = unique(school_names[order(`median_real_price_2008-2012`)]))]
site_page <- ggplot(sites, aes(y = school_names)) +
  geom_segment(aes(x = `median_real_price_2008-2012`, xend = `median_real_price_2014-2018`, yend = school_names),
               color = "#B8BFC2", linewidth = 0.5) +
  geom_point(aes(x = `median_real_price_2008-2012`), shape = 21, fill = "white", color = "#5B666B", size = 1.8) +
  geom_point(aes(x = `median_real_price_2014-2018`, color = group), size = 1.8) +
  facet_wrap(~group, scales = "free_y") +
  scale_color_manual(values = colors, guide = "none") +
  scale_x_log10(labels = scales::label_dollar(scale = 1e-3, suffix = "k", accuracy = 1),
                breaks = c(3e4, 1e5, 3e5, 1e6)) +
  labs(title = "Site median sale price before and after",
       subtitle = "2008-2012 (open circle) to 2014-2018 (filled); all property within a quarter mile",
       x = "Median price (log scale)", y = NULL,
       caption = "Sites with sales in both periods. Each site's comparison mixes whichever homes sold; no characteristic adjustment.") +
  theme(axis.text.y = element_text(size = 6.5))
pages <- c(pages, list(site_page))

pdf("../output/sample_summary.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
for (page in pages) print(page)
invisible(dev.off())
