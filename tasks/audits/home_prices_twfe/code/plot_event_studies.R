# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

estimates <- readRDS("../output/twfe.rds")
coefficients <- estimates$coefficients
models <- estimates$models
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
                     "by school site; each sale has equal weight. Hedonics: size, lot, age, rooms, beds, baths, residence type, quality,",
                     "condition, REO and quick-resale indicators, 2-6-unit indicator; no property-class dummies. Shaded: 2013.", sep = "\n")

# The 2012 reference year is zero by construction and is drawn as such.
events <- rbind(coefficients[design == "event", .(sample, variant, controls, sale_year, estimate, ci_low, ci_high)],
                unique(coefficients[design == "event", .(sample, variant, controls)])[
                  , `:=`(sale_year = 2012L, estimate = 0, ci_low = 0, ci_high = 0)])
events[, `:=`(controls = factor(controls, levels = control_levels), variant = factor(variant, levels = variant_levels))]
event_page <- function(control_name) {
  ggplot(events[controls == control_name], aes(sale_year, estimate)) +
    annotate("rect", xmin = 2012.5, xmax = 2013.5, ymin = -Inf, ymax = Inf, fill = "#EEF0F1") +
    geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4) +
    geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, color = colors[[control_name]]) +
    geom_point(size = 1.7, color = colors[[control_name]], shape = shapes[[control_name]]) +
    facet_grid(sample ~ variant, labeller = label_wrap_gen(width = 18)) +
    scale_x_continuous(breaks = seq(2008, 2018, 2)) +
    labs(title = paste0("Event studies, log real sale price (", tolower(control_name), ")"),
         subtitle = "Closed relative to stayed-open sites; 2012 = 0",
         x = NULL, y = "Log points", caption = sample_note)
}

did <- merge(coefficients[design == "did", .(sample, variant, controls, estimate, ci_low, ci_high)],
             models[design == "event", .(sample, variant, controls, pre_trend_p_value)],
             by = c("sample", "variant", "controls"))
did[, `:=`(controls = factor(controls, levels = control_levels), variant = factor(variant, levels = rev(variant_levels)))]
dodge <- position_dodge(width = 0.5)
did_page <- ggplot(did, aes(estimate, variant, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.5, position = dodge) +
  geom_point(size = 2.2, position = dodge) +
  geom_text(aes(x = max(did$ci_high) + 0.02, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            position = dodge, hjust = 0, size = 3, color = "#52514e", show.legend = FALSE) +
  facet_wrap(~sample, ncol = 1) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.4))) +
  labs(title = "Pooled difference-in-differences: 2014-2018 vs 2008-2012 (2013 omitted)",
       x = "Closed minus stayed-open change in log real price", y = NULL,
       caption = paste("95% intervals clustered by school site. Pre-trend p: joint test that the 2008-2011 event coefficients are zero.",
                       "Quarter-mile samples as in the event-study pages.", sep = "\n"))

pdf("../output/event_studies.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
print(event_page("Hedonics"))
print(event_page("Site and year effects"))
print(did_page)
invisible(dev.off())
