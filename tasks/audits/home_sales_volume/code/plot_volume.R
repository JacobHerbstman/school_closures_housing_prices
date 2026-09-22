# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_sales_volume/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

volume <- readRDS("../output/volume.rds")
measure_levels <- c("All market sales", "Clean price-sample sales", "Clean sales excluding REO", "REO resales")
group_colors <- c("Closed" = "#AF493D", "Stayed open" = "#1F6FAE")
estimate_color <- "#2a78d6"
theme_set(theme_minimal(base_size = 11) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E6E8E9", linewidth = 0.3),
  legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold"),
  plot.title = element_text(face = "bold"), plot.caption = element_text(color = "#52514e", hjust = 0)))
note <- paste("Sales within a quarter mile of a closed (stayed-open) site and not the other group, excluding sales near welcoming schools,",
              "other candidates, and vacated welcoming buildings; 29 closed and 48 stayed-open sites, zero-sale site-years included.",
              "Market sales: all single-parcel non-condo sales passing the county flags above $10,000 (includes foreclosure auctions).", sep = "\n")
shade <- annotate("rect", xmin = 2012.5, xmax = 2013.5, ymin = -Inf, ymax = Inf, fill = "#EEF0F1")

annual <- copy(volume$annual[tier == "All sites"])[, `:=`(group = fifelse(treated == 1L, "Closed", "Stayed open"),
                                     measure = factor(measure, levels = measure_levels))]
trends_page <- ggplot(annual, aes(sale_year, mean_sales_per_site, color = group)) +
  shade +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  facet_grid(property ~ measure, scales = "free_y", labeller = label_wrap_gen(width = 20)) +
  scale_color_manual(values = group_colors) +
  scale_x_continuous(breaks = seq(2008, 2018, 2)) +
  labs(title = "Sales per school site by year", x = NULL, y = "Mean sales per site", caption = note)

all_events <- rbind(volume$events[, .(property, tier, measure, sale_year, estimate, ci_low, ci_high)],
                    unique(volume$events[, .(property, tier, measure)])[, `:=`(sale_year = 2012L, estimate = 0, ci_low = 0, ci_high = 0)])
events <- all_events[tier == "All sites"]
events[, measure := factor(measure, levels = measure_levels)]
event_page <- ggplot(events, aes(sale_year, estimate)) +
  shade + geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, color = estimate_color) +
  geom_point(size = 1.7, color = estimate_color) +
  facet_grid(property ~ measure, labeller = label_wrap_gen(width = 20)) +
  scale_x_continuous(breaks = seq(2008, 2018, 2)) +
  labs(title = "Event studies: sales volume, closed relative to stayed-open sites",
       subtitle = "Poisson with site and year effects; 2012 = 0; log points (0.1 is about 10 percent)",
       x = NULL, y = "Log points", caption = paste(note, "95% intervals clustered by school site.", sep = "\n"))

did <- copy(volume$did[tier == "All sites"])[, measure := factor(measure, levels = rev(measure_levels))]
did_page <- ggplot(did, aes(estimate, measure)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.6, color = estimate_color) +
  geom_point(size = 2.4, color = estimate_color) +
  geom_text(aes(x = max(did$ci_high) + 0.03, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            hjust = 0, size = 3, color = "#52514e") +
  facet_wrap(~property, ncol = 1) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.35))) +
  labs(title = "Pooled difference-in-differences in sales volume: 2014-2018 vs 2008-2012 (2013 omitted)",
       x = "Closed minus stayed-open change in log expected sales", y = NULL,
       caption = "Poisson with site and year effects; 95% intervals clustered by school site. Pre-trend p: joint test of the 2008-2011 event coefficients.")

# Baseline price tiers (from the price analysis): closed vs stayed-open sites in the same tier.
tier_levels <- c("Lower-price sites", "Higher-price sites")
property_colors <- c("All property" = "#2a78d6", "Single-family" = "#eb6834")
property_shapes <- c("All property" = 16, "Single-family" = 17)
tier_note <- "Tiers: each site's 2008-2012 median real price among clean sales, split at the median of site medians across both groups."
tier_annual <- copy(volume$annual[tier != "All sites" & property == "All property"])[
  , `:=`(group = fifelse(treated == 1L, "Closed", "Stayed open"), measure = factor(measure, levels = measure_levels),
         tier = factor(tier, levels = tier_levels))]
tier_trends_page <- ggplot(tier_annual, aes(sale_year, mean_sales_per_site, color = group)) +
  shade + geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  facet_grid(tier ~ measure, scales = "free_y", labeller = label_wrap_gen(width = 20)) +
  scale_color_manual(values = group_colors) +
  scale_x_continuous(breaks = seq(2008, 2018, 2)) +
  labs(title = "Sales per school site by year and baseline price tier, all property", x = NULL,
       y = "Mean sales per site", caption = paste(tier_note, note, sep = "\n"))
tier_events <- all_events[tier != "All sites"][, `:=`(measure = factor(measure, levels = measure_levels),
                                                        tier = factor(tier, levels = tier_levels))]
volume_dodge <- position_dodge(width = 0.5)
tier_event_page <- ggplot(tier_events, aes(sale_year, estimate, color = property, shape = property)) +
  shade + geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, position = volume_dodge) +
  geom_point(size = 1.6, position = volume_dodge) +
  facet_grid(tier ~ measure, labeller = label_wrap_gen(width = 20)) +
  scale_color_manual(values = property_colors) + scale_shape_manual(values = property_shapes) +
  scale_x_continuous(breaks = seq(2008, 2018, 2)) +
  labs(title = "Event studies: sales volume by baseline price tier", subtitle = "Poisson with site and year effects; 2012 = 0",
       x = NULL, y = "Log points", caption = paste(tier_note, "95% intervals clustered by school site.", sep = "\n"))
tier_did <- copy(volume$did[tier != "All sites"])[, `:=`(measure = factor(measure, levels = rev(measure_levels)),
                                                          tier = factor(tier, levels = tier_levels))]
tier_did_page <- ggplot(tier_did, aes(estimate, measure, color = property, shape = property)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.6, position = volume_dodge) +
  geom_point(size = 2.2, position = volume_dodge) +
  geom_text(aes(x = max(tier_did$ci_high) + 0.03, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            position = volume_dodge, hjust = 0, size = 3, color = "#52514e", show.legend = FALSE) +
  facet_wrap(~tier, ncol = 1) +
  scale_color_manual(values = property_colors) + scale_shape_manual(values = property_shapes) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.35))) +
  labs(title = "Pooled difference-in-differences in sales volume by baseline price tier",
       x = "Closed minus stayed-open change in log expected sales", y = NULL,
       caption = paste(tier_note, "Poisson with site and year effects; 95% intervals clustered by school site.", sep = "\n"))

pdf("../output/volume.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
print(trends_page)
print(event_page)
print(did_page)
print(tier_trends_page)
print(tier_event_page)
print(tier_did_page)
invisible(dev.off())
