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
control_levels <- c("Fixed effects only", "Fixed effects + hedonics", "Fixed effects + hedonics + neighborhood trends")
variant_levels <- c("All clean sales", "Drop REO resales", "Drop resales within 365 days",
                    "Drop 1st-99th price tails", "Drop all flagged sales")
colors <- setNames(c("#2a78d6", "#eb6834", "#1baf7a"), control_levels)
shapes <- setNames(c(16, 17, 15), control_levels)
short_controls <- setNames(c("FE only", "FE + hedonics", "FE + hedonics + trends"), control_levels)
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
tier_events <- all_events[tier %in% tier_levels & variant == "All clean sales" & normalization == "2012"]
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

tier_pooled <- merge(all_did[tier %in% tier_levels], all_models[design == "event" & tier %in% tier_levels,
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

# Quartiles and the continuous gradient in baseline price.
quartile_levels <- paste("Price quartile", 1:4)
quartile_counts <- estimates$site_tiers[, .(closed = sum(treated == 1L), open = sum(treated == 0L),
                                            median_baseline = median(pre_median_real_price)), by = .(tier = price_quartile)]
quartile_events <- all_events[tier %in% quartile_levels & variant == "All clean sales" & normalization == "2012"]
quartile_events <- rbind(quartile_events, unique(quartile_events[, .(sample, tier, variant, controls, weighting, normalization)])[
  , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
quartile_events <- merge(quartile_events, quartile_counts, by = "tier")
quartile_events[, `:=`(panel = factor(sprintf("%s: %d closed / %d open, median $%sk", tier, closed, open, round(median_baseline / 1e3)),
                                      levels = unique(sprintf("%s: %d closed / %d open, median $%sk", tier, closed, open,
                                                              round(median_baseline / 1e3))[order(tier)])),
                       controls = factor(controls, levels = control_levels))]
quartile_event_page <- ggplot(quartile_events, aes(sale_year, estimate, color = controls, shape = controls)) +
  shade + zero +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.4, position = tier_dodge) +
  geom_point(size = 1.5, position = tier_dodge) +
  facet_grid(sample ~ panel, labeller = label_wrap_gen(width = 22)) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(breaks = seq(2008, 2018, 2)) +
  labs(title = "Event studies by baseline price quartile, log real sale price, all clean sales",
       subtitle = "Closed vs stayed-open sites within the same quartile of 2008-2012 site median price; 2012 = 0",
       x = NULL, y = "Log points", caption = sample_note)

quartile_points <- merge(all_did[tier %in% quartile_levels & variant %in% c("All clean sales", "Drop REO resales")],
                         quartile_counts, by = "tier")
curve <- copy(estimates$gradient_curve)[, controls := factor(controls, levels = control_levels)]
quartile_points[, controls := factor(controls, levels = control_levels)]
gradient_terms <- dcast(estimates$gradient, sample + variant + controls ~ term, value.var = c("estimate", "ci_low", "ci_high"))
gradient_labels <- gradient_terms[, .(sample, variant, controls, label = sprintf("%s slope: %.2f [%.2f, %.2f]",
  short_controls[controls],
  `estimate_Slope per log point of baseline price`, `ci_low_Slope per log point of baseline price`,
  `ci_high_Slope per log point of baseline price`))]
gradient_labels[, `:=`(y = c(0.64, 0.54, 0.44)[match(controls, control_levels)],
                       controls = factor(controls, levels = control_levels))]
gradient_page <- ggplot(curve, aes(baseline_price, estimate, color = controls, fill = controls)) +
  geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.12, color = NA) +
  geom_line(linewidth = 0.9) +
  geom_pointrange(data = quartile_points, aes(x = median_baseline, y = estimate, ymin = ci_low, ymax = ci_high, shape = controls),
                  position = position_dodge(width = 0.08), size = 0.35, linewidth = 0.5) +
  geom_text(data = gradient_labels, aes(x = min(curve$baseline_price), y = y, label = label), hjust = 0, size = 3,
            show.legend = FALSE) +
  facet_grid(sample ~ variant) +
  scale_x_log10(labels = scales::label_dollar(scale = 1e-3, suffix = "k", accuracy = 1)) +
  scale_color_manual(values = colors) + scale_fill_manual(values = colors, guide = "none") +
  scale_shape_manual(values = shapes) +
  coord_cartesian(ylim = c(-0.8, 0.7)) +
  labs(title = "Closure effect on log price by the site's baseline price level",
       subtitle = "Lines: continuous interaction with 95% bands; points: separate estimates within each baseline-price quartile",
       x = "Site median sale price, 2008-2012 (2022 dollars, log scale)", y = "Closed minus stayed-open change, 2014-2018 vs 2008-2012",
       caption = paste("The continuous model adds year effects that vary with baseline price for all sites. Slope: change in the",
                       "closure effect per log point of baseline price (about 2.7 times higher). 95% intervals clustered by school site.", sep = "\n"))

slope_events <- rbind(estimates$gradient_events[variant == "All clean sales"],
                      unique(estimates$gradient_events[variant == "All clean sales", .(sample, variant, controls)])[
                        , `:=`(sale_year = 2012L, estimate = 0, std_error = 0, ci_low = 0, ci_high = 0)])
slope_events[, controls := factor(controls, levels = control_levels)]
slope_page <- ggplot(slope_events, aes(sale_year, estimate, color = controls, shape = controls)) +
  shade + zero +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, position = average_dodge) +
  geom_point(size = 1.9, position = average_dodge) +
  facet_wrap(~sample) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(breaks = 2008:2018) +
  labs(title = "Year-by-year gradient: how the closure effect varies with baseline price",
       subtitle = "Coefficient on closed x log baseline price in each year, relative to 2012; all clean sales",
       x = NULL, y = "Log points per log point of baseline price",
       caption = "The model also includes year effects varying with baseline price for all sites. 95% intervals clustered by school site.")

# Balance: were closed sites already changing differently before 2013?
trend_labels <- c(change_ba_share = "Bachelor's degree share (pp)", change_nh_white_share = "Non-Hispanic white share (pp)",
                  change_nh_black_share = "Non-Hispanic Black share (pp)", change_log_mean_income = "Log real mean household income")
site_trends <- melt(estimates$site_trends, id.vars = c("school_site_id", "treated", "price_tier", "price_quartile", "pre_median_real_price"),
                    variable.name = "measure")
site_trends[, `:=`(group = fifelse(treated == 1L, "Closed", "Stayed open"), measure = factor(trend_labels[as.character(measure)], levels = trend_labels),
                   price_quartile = factor(price_quartile, levels = rev(quartile_levels)))]
trend_means <- site_trends[, .(value = mean(value, na.rm = TRUE)), by = .(measure, price_quartile, group)]
balance_page <- ggplot(site_trends, aes(value, price_quartile, color = group)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_point(position = position_jitterdodge(jitter.height = 0.12, dodge.width = 0.6, seed = 1), size = 1.3, alpha = 0.55) +
  geom_point(data = trend_means, position = position_dodge(width = 0.6), size = 3.2, shape = 18) +
  facet_wrap(~measure, scales = "free_x") +
  scale_color_manual(values = c("Closed" = "#AF493D", "Stayed open" = "#1F6FAE")) +
  labs(title = "Tract change from 2000 to 2008-2012 around each school site, by baseline price quartile",
       subtitle = "Small points: sites (average over their 2008-2012 sales); diamonds: group means",
       x = "Change, 2000 to 2008-2012", y = NULL,
       caption = paste("Tracts from 2010 boundaries; 2000 Census SF3 allocated to 2010 tracts by population share. Income in 2012 dollars.",
                       "Quartiles of each site's 2008-2012 median sale price.", sep = "\n"))

# Leave one top-quartile closed site out.
top_loo <- copy(estimates$top_quartile_leave_one_out)
top_loo[, `:=`(site_label = sprintf("%s (%d sales)", substr(site_name, 1, 34), dropped_site_sales),
               controls = factor(controls, levels = control_levels))]
top_loo[, site_label := factor(site_label, levels = unique(site_label[order(-dropped_site_sales)]))]
top_full <- rbind(
  all_did[tier == "Price quartile 4" & variant == "All clean sales" & weighting == "Transactions",
          .(sample, controls, estimand = "Top-quartile pooled effect", estimate)],
  estimates$gradient[variant == "All clean sales" & term == "Slope per log point of baseline price",
                     .(sample, controls, estimand = "Gradient slope", estimate)])
top_full[, controls := factor(controls, levels = control_levels)]
loo_dodge <- position_dodge(width = 0.6)
top_loo_page <- ggplot(top_loo, aes(estimate, site_label, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_vline(data = top_full, aes(xintercept = estimate, color = controls), linetype = "dashed", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.4, position = loo_dodge) +
  geom_point(size = 1.8, position = loo_dodge) +
  facet_grid(sample ~ estimand, scales = "free") +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  labs(title = "Dropping each top-quartile closed site in turn",
       subtitle = "Top-quartile pooled log-price effect (2014-2018 vs 2008-2012) and the continuous gradient slope; dashed: all sites",
       x = "Estimate", y = "Dropped closed site",
       caption = "All clean sales. Sites ordered by their number of sales. 95% intervals clustered by school site.")

pdf("../output/event_studies.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
print(variant_page("Fixed effects + hedonics"))
print(variant_page("Fixed effects only"))
print(did_page)
print(average_page)
print(loo_2010_page)
print(spaghetti_page)
print(tier_event_page)
print(tier_did_page)
print(quartile_event_page)
print(gradient_page)
print(slope_page)
print(balance_page)
print(top_loo_page)
invisible(dev.off())
