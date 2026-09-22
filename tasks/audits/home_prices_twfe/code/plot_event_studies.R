# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

estimates <- readRDS("../output/twfe.rds")
# The first six pages use all sites; the last two split by baseline price tier.
all_events <- estimates$events
all_did <- estimates$did
all_models <- estimates$models
events <- all_events[tier == "All sites"]
did <- all_did[tier == "All sites"]
models <- all_models[tier == "All sites"]
leave_one_out <- estimates$leave_one_out
control_levels <- c("Site and year effects", "Hedonics")
variant_levels <- c("All clean sales", "Drop REO resales", "Drop resales within 365 days",
                    "Drop 1st-99th price tails", "Drop all flagged sales")
colors <- setNames(c("#2a78d6", "#eb6834"), control_levels)
shapes <- setNames(c(16, 17), control_levels)
theme_set(theme_minimal(base_size = 11) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E6E8E9", linewidth = 0.3),
  legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold"),
  plot.title = element_text(face = "bold"), plot.caption = element_text(color = "#52514e", hjust = 0)))
sample_note <- paste("Sales within a quarter mile of a closed (stayed-open) site and not the other group, excluding sales near welcoming",
                     "schools, other candidates, and vacated welcoming buildings. Site and year fixed effects; 95% intervals clustered",
                     "by school site. Hedonics: size, lot, age, rooms, beds, baths, residence type, quality, condition, REO and",
                     "quick-resale indicators, 2-6-unit indicator; no property-class dummies. Shaded: 2013.", sep = "\n")
shade <- annotate("rect", xmin = 2012.5, xmax = 2013.5, ymin = -Inf, ymax = Inf, fill = "#EEF0F1")
zero <- geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4)

# Relative to 2012, the reference year is zero by construction and is drawn as such.
relative_2012 <- events[normalization == "2012"]
relative_2012 <- rbind(relative_2012, unique(relative_2012[, .(sample, tier, variant, controls, weighting, normalization)])[
  , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
relative_2012[, variant := factor(variant, levels = variant_levels)]
variant_page <- function(control_name) {
  ggplot(relative_2012[controls == control_name & weighting == "Transactions"], aes(sale_year, estimate)) +
    shade + zero +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, color = colors[[control_name]]) +
    geom_point(size = 1.7, color = colors[[control_name]], shape = shapes[[control_name]]) +
    facet_grid(sample ~ variant, labeller = label_wrap_gen(width = 18)) +
    scale_x_continuous(breaks = seq(2008, 2018, 2)) +
    labs(title = paste0("Event studies, log real sale price (", tolower(control_name), ")"),
         subtitle = "Closed relative to stayed-open sites; 2012 = 0; each sale has equal weight",
         x = NULL, y = "Log points", caption = sample_note)
}

pooled <- merge(did, models[design == "event", .(sample, variant, controls, weighting, pre_trend_p_value)],
                by = c("sample", "variant", "controls", "weighting"))
pooled[, row := fifelse(weighting == "Site-years", paste(variant, "(site-year weights)"), variant)]
pooled[, `:=`(controls = factor(controls, levels = control_levels),
              row = factor(row, levels = rev(c(variant_levels, "All clean sales (site-year weights)"))))]
dodge <- position_dodge(width = 0.5)
did_page <- ggplot(pooled, aes(estimate, row, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.5, position = dodge) +
  geom_point(size = 2.2, position = dodge) +
  geom_text(aes(x = max(pooled$ci_high) + 0.02, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            position = dodge, hjust = 0, size = 3, color = "#52514e", show.legend = FALSE) +
  facet_wrap(~sample, ncol = 1) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.4))) +
  labs(title = "Pooled difference-in-differences: 2014-2018 vs 2008-2012 (2013 omitted)",
       x = "Closed minus stayed-open change in log real price", y = NULL,
       caption = paste("95% intervals clustered by school site. Pre-trend p: joint test that the 2008-2011 event coefficients are zero",
                       "(relative to 2012). Site-year weights give each school site equal total weight in each year.", sep = "\n"))

average_dodge <- position_dodge(width = 0.5)
averages <- events[normalization == "2008-2012 average" & variant == "All clean sales"]
averages[, `:=`(weighting = factor(weighting, levels = c("Transactions", "Site-years")),
                controls = factor(controls, levels = control_levels))]
average_page <- ggplot(averages,
                       aes(sale_year, estimate, color = controls, shape = controls)) +
  shade + zero +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, position = average_dodge) +
  geom_point(size = 1.9, position = average_dodge) +
  facet_grid(sample ~ weighting, labeller = labeller(weighting = c(Transactions = "Equal weight per sale",
                                                                   `Site-years` = "Equal weight per site-year"))) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(breaks = 2008:2018) +
  labs(title = "Event studies relative to the 2008-2012 average, all clean sales",
       subtitle = "Same regressions as before; each year is shown against the average of its 2008-2012 coefficients",
       x = NULL, y = "Log points relative to the 2008-2012 average", caption = sample_note)

full <- events[variant == "All clean sales" & weighting == "Transactions"]
loo_2010 <- leave_one_out[normalization == "2012" & sale_year == 2010L]
loo_2010[, site_label := sprintf("%s (%d sales)", substr(site_name, 1, 38), dropped_site_sales)]
loo_2010[, site_label := factor(site_label, levels = unique(site_label[order(estimate)]))]
full_2010 <- full[normalization == "2012" & sale_year == 2010L]
loo_2010_page <- ggplot(loo_2010, aes(estimate, site_label, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_vline(data = full_2010, aes(xintercept = estimate, color = controls), linetype = "dashed", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.3, alpha = 0.5) +
  geom_point(size = 1.5) +
  facet_grid(sample ~ controls, scales = "free_y") +
  scale_color_manual(values = colors, guide = "none") + scale_shape_manual(values = shapes, guide = "none") +
  labs(title = "2010 event coefficient (relative to 2012) when each closed site is dropped",
       subtitle = "All clean sales, equal weight per sale; dashed line: all sites", x = "Log points", y = "Dropped site",
       caption = "95% intervals clustered by school site.") +
  theme(axis.text.y = element_text(size = 5.5))

loo_paths <- leave_one_out[normalization == "2008-2012 average"]
spaghetti_page <- ggplot(loo_paths, aes(sale_year, estimate)) +
  shade + zero +
  geom_line(aes(group = dropped_site), color = "#B8BFC2", linewidth = 0.3) +
  geom_line(data = full[normalization == "2008-2012 average"], aes(color = controls), linewidth = 0.9) +
  geom_point(data = full[normalization == "2008-2012 average"], aes(color = controls), size = 1.6) +
  facet_grid(sample ~ controls) +
  scale_color_manual(values = colors, guide = "none") +
  scale_x_continuous(breaks = 2008:2018) +
  labs(title = "Event paths dropping each closed site in turn (gray) and with all sites (color)",
       subtitle = "Relative to the 2008-2012 average; all clean sales, equal weight per sale",
       x = NULL, y = "Log points relative to the 2008-2012 average")

tier_levels <- c("Lower-price sites", "Higher-price sites")
tier_counts <- estimates$site_tiers[, .(sites = .N), by = .(price_tier, treated)]
tier_note <- paste0("Tiers: each site's 2008-2012 median real price, split at the median of site medians. Lower-price: ",
  tier_counts[price_tier == tier_levels[1] & treated == 1L, sites], " closed / ",
  tier_counts[price_tier == tier_levels[1] & treated == 0L, sites], " stayed-open sites; higher-price: ",
  tier_counts[price_tier == tier_levels[2] & treated == 1L, sites], " closed / ",
  tier_counts[price_tier == tier_levels[2] & treated == 0L, sites], " stayed-open sites.")
tier_events <- all_events[tier != "All sites" & variant == "All clean sales" & normalization == "2012"]
tier_events <- rbind(tier_events, unique(tier_events[, .(sample, tier, variant, controls, weighting, normalization)])[
  , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
tier_events[, `:=`(tier = factor(tier, levels = tier_levels), controls = factor(controls, levels = control_levels))]
tier_dodge <- position_dodge(width = 0.5)
tier_event_page <- ggplot(tier_events, aes(sale_year, estimate, color = controls, shape = controls)) +
  shade + zero +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, position = tier_dodge) +
  geom_point(size = 1.9, position = tier_dodge) +
  facet_grid(sample ~ tier) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(breaks = 2008:2018) +
  labs(title = "Event studies by baseline price tier, log real sale price, all clean sales",
       subtitle = "Closed vs stayed-open sites within the same tier; 2012 = 0; each sale has equal weight",
       x = NULL, y = "Log points", caption = paste(tier_note, sample_note, sep = "\n"))

tier_pooled <- merge(all_did[tier != "All sites"], all_models[design == "event" & tier != "All sites",
                     .(sample, tier, variant, controls, weighting, pre_trend_p_value)],
                     by = c("sample", "tier", "variant", "controls", "weighting"))
tier_pooled[, row := factor(paste(tier, variant, sep = ": "),
                            levels = rev(as.vector(outer(tier_levels, c("All clean sales", "Drop REO resales"), paste, sep = ": "))))]
tier_pooled[, controls := factor(controls, levels = control_levels)]
tier_did_page <- ggplot(tier_pooled, aes(estimate, row, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.5, position = dodge) +
  geom_point(size = 2.2, position = dodge) +
  geom_text(aes(x = max(tier_pooled$ci_high) + 0.02, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            position = dodge, hjust = 0, size = 3, color = "#52514e", show.legend = FALSE) +
  facet_wrap(~sample, ncol = 1) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.4))) +
  labs(title = "Pooled difference-in-differences by baseline price tier: 2014-2018 vs 2008-2012",
       x = "Closed minus stayed-open change in log real price", y = NULL,
       caption = paste(tier_note, "95% intervals clustered by school site.", sep = "\n"))

pdf("../output/event_studies.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
print(variant_page("Hedonics"))
print(variant_page("Site and year effects"))
print(did_page)
print(average_page)
print(loo_2010_page)
print(spaghetti_page)
print(tier_event_page)
print(tier_did_page)
invisible(dev.off())
