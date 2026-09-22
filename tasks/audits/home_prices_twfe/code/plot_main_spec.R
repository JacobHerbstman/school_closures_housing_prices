# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

# The main specification only: fixed effects plus hedonics, all clean sales,
# equal weight per sale, quarter mile. Robustness is in event_studies.pdf.
estimates <- readRDS("../output/twfe.rds")
main_controls <- "Fixed effects + hedonics"
color <- "#eb6834"
theme_set(theme_minimal(base_size = 12) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E6E8E9", linewidth = 0.3),
  strip.text = element_text(face = "bold"), plot.title = element_text(face = "bold"),
  plot.caption = element_text(color = "#52514e", hjust = 0)))
note <- paste("Sales within a quarter mile of a closed (stayed-open) site and not the other group, excluding sales near welcoming",
              "schools, other candidates, and vacated welcoming buildings. Log real price; site and year fixed effects plus hedonics",
              "(size, lot, age, rooms, beds, baths, residence type, quality, condition, REO and quick-resale indicators, 2-6-unit",
              "indicator); all clean sales, equal weight per sale; 95% intervals clustered by school site. Shaded: 2013.", sep = "\n")
shade <- annotate("rect", xmin = 2012.5, xmax = 2013.5, ymin = -Inf, ymax = Inf, fill = "#EEF0F1")
zero <- geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4)

# Event coefficients relative to 2012, with the reference year drawn at zero.
main_events <- estimates$events[controls == main_controls & variant == "All clean sales" &
                                  weighting == "Transactions" & normalization == "2012"]
main_events <- rbind(main_events, unique(main_events[, .(sample, tier, variant, controls, weighting, normalization)])[
  , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
main_did <- estimates$did[controls == main_controls & variant == "All clean sales" & weighting == "Transactions"]
event_plot <- function(data, facets, title) {
  ggplot(data, aes(sale_year, estimate)) +
    shade + zero +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.6, color = color) +
    geom_point(size = 2.2, color = color) +
    facets +
    scale_x_continuous(breaks = 2008:2018) +
    labs(title = title, subtitle = "Closed relative to stayed-open sites; 2012 = 0", x = NULL,
         y = "Log points", caption = note)
}
pooled_label <- function(tiers) {
  labels <- main_did[tier %in% tiers, .(sample, tier = factor(tier, levels = tiers),
                                        label = sprintf("Pooled 2014-18 vs 2008-12: %.3f [%.2f, %.2f]", estimate, ci_low, ci_high))]
  geom_text(data = labels, aes(x = 2007.7, y = Inf, label = label), hjust = 0, vjust = 1.4, size = 3.2,
            color = "#52514e", inherit.aes = FALSE)
}

all_sites_page <- event_plot(main_events[tier == "All sites"], facet_wrap(~sample), "Event study, all study sites") +
  pooled_label("All sites")

tier_levels <- c("Lower-price sites", "Higher-price sites")
tier_events <- main_events[tier %in% tier_levels][, tier := factor(tier, levels = tier_levels)]
tier_page <- event_plot(tier_events, facet_grid(sample ~ tier), "Event study by baseline price tier") +
  pooled_label(tier_levels) +
  labs(caption = paste("Tiers: each site's 2008-2012 median real sale price, split at the median of site medians (14 closed / 25",
                       "stayed-open lower-price sites; 15 / 23 higher-price).", note, sep = "\n"))

quartile_levels <- paste("Price quartile", 1:4)
quartiles <- estimates$site_tiers[, .(closed = sum(treated == 1L), open = sum(treated == 0L),
                                      median_baseline = median(pre_median_real_price)), by = .(tier = price_quartile)]
quartile_events <- merge(main_events[tier %in% quartile_levels], quartiles, by = "tier")
quartile_events[, panel := sprintf("Quartile %s: %d closed / %d open\nmedian $%sk", sub("Price quartile ", "", tier),
                                   closed, open, round(median_baseline / 1e3))]
quartile_page <- event_plot(quartile_events, facet_grid(sample ~ panel), "Event study by baseline price quartile") +
  scale_x_continuous(breaks = seq(2008, 2018, 2))

curve <- estimates$gradient_curve[controls == main_controls & variant == "All clean sales"]
quartile_points <- merge(main_did[tier %in% quartile_levels], quartiles, by = "tier")
slopes <- estimates$gradient[controls == main_controls & variant == "All clean sales" &
                               term == "Slope per log point of baseline price",
                             .(sample, label = sprintf("Slope: %.3f [%.2f, %.2f] per log point of baseline price",
                                                       estimate, ci_low, ci_high))]
gradient_page <- ggplot(curve, aes(baseline_price, estimate)) +
  zero +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = color, alpha = 0.15) +
  geom_line(linewidth = 1, color = color) +
  geom_pointrange(data = quartile_points, aes(x = median_baseline, ymin = ci_low, ymax = ci_high),
                  color = "#52514e", size = 0.4, linewidth = 0.6) +
  geom_text(data = slopes, aes(x = min(curve$baseline_price), y = Inf, label = label), hjust = 0, vjust = 1.4,
            size = 3.2, color = "#52514e") +
  facet_wrap(~sample) +
  scale_x_log10(labels = scales::label_dollar(scale = 1e-3, suffix = "k", accuracy = 1)) +
  coord_cartesian(ylim = c(-0.7, 0.7)) +
  labs(title = "Closure effect by the site's baseline price level",
       subtitle = "Line: continuous interaction with 95% band; gray points: separate estimates within each quartile",
       x = "Site median sale price, 2008-2012 (2022 dollars, log scale)",
       y = "Closed minus stayed-open change,\n2014-2018 vs 2008-2012 (log points)",
       caption = paste("The continuous model also lets year effects vary with baseline price for all sites.", note, sep = "\n"))

slope_events <- estimates$gradient_events[controls == main_controls & variant == "All clean sales"]
slope_events <- rbind(slope_events, unique(slope_events[, .(sample, variant, controls)])[
  , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
slope_page <- event_plot(slope_events, facet_wrap(~sample), "Year-by-year gradient in baseline price") +
  labs(subtitle = "Coefficient on closed x log baseline price in each year, relative to 2012",
       y = "Log points per log point of baseline price")

pdf("../output/main_spec.pdf", width = 11, height = 7.5, onefile = TRUE, useDingbats = FALSE)
print(all_sites_page)
print(tier_page)
print(quartile_page)
print(gradient_page)
print(slope_page)
invisible(dev.off())
