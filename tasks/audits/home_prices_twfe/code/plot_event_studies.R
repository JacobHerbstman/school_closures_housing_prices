# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/tasks/audits/home_prices_twfe/code")
suppressPackageStartupMessages({library(data.table); library(ggplot2)})

estimates <- readRDS("../output/twfe.rds")
coefficients <- estimates$coefficients
models <- estimates$models
control_levels <- c("Site and year effects", "Hedonics", "Hedonics and unit count")
colors <- setNames(c("#2a78d6", "#eb6834", "#1baf7a"), control_levels)
shapes <- setNames(c(16, 17, 15), control_levels)
theme_set(theme_minimal(base_size = 12) + theme(
  panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#E6E8E9", linewidth = 0.3),
  legend.position = "top", legend.title = element_blank(), strip.text = element_text(face = "bold"),
  plot.title = element_text(face = "bold"), plot.caption = element_text(color = "#52514e", hjust = 0)))

# The 2012 reference year is zero by construction and is drawn as such.
events <- rbind(coefficients[design == "event", .(sample, controls, sale_year, estimate, ci_low, ci_high)],
                unique(coefficients[design == "event", .(sample, controls)])[, `:=`(sale_year = 2012L, estimate = 0, ci_low = 0, ci_high = 0)])
events[, controls := factor(controls, levels = control_levels)]
dodge <- position_dodge(width = 0.55)
event_page <- ggplot(events, aes(sale_year, estimate, color = controls, shape = controls)) +
  annotate("rect", xmin = 2012.5, xmax = 2013.5, ymin = -Inf, ymax = Inf, fill = "#EEF0F1") +
  geom_hline(yintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0, linewidth = 0.5, position = dodge) +
  geom_point(size = 1.9, position = dodge) +
  facet_wrap(~sample) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(breaks = 2008:2018) +
  labs(title = "Event studies: log real sale price, closed relative to stayed-open sites",
       x = NULL, y = "Difference relative to 2012 (log points)",
       caption = paste("Site and year fixed effects; 95% intervals clustered by school site; each sale has equal weight.",
                       "Hedonics: size, lot, age, rooms, beds, baths, residence type, quality, condition, REO and quick-resale indicators,",
                       "and a 2-6-unit indicator, replaced by a unit-count factor with an unknown level in the last set. No property-class dummies.",
                       "Shaded: 2013 (proposal March 21, closures end of June).", sep = "\n"))

did <- merge(coefficients[design == "did", .(sample, controls, estimate, ci_low, ci_high)],
             models[design == "event", .(sample, controls, pre_trend_p_value)], by = c("sample", "controls"))
did[, `:=`(controls = factor(controls, levels = control_levels),
           sample = factor(sample, levels = rev(sort(unique(sample)))))]
did_page <- ggplot(did, aes(estimate, sample, color = controls, shape = controls)) +
  geom_vline(xintercept = 0, color = "#52514e", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = ci_low, xmax = ci_high), height = 0, linewidth = 0.5,
                 position = position_dodge(width = 0.5)) +
  geom_point(size = 2.2, position = position_dodge(width = 0.5)) +
  geom_text(aes(x = max(did$ci_high) + 0.02, label = sprintf("pre-trend p = %.2f", pre_trend_p_value)),
            position = position_dodge(width = 0.5), hjust = 0, size = 3, color = "#52514e", show.legend = FALSE) +
  scale_color_manual(values = colors) + scale_shape_manual(values = shapes) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.35))) +
  labs(title = "Pooled difference-in-differences: 2014-2018 vs 2008-2012 (2013 omitted)",
       x = "Closed minus stayed-open change in log real price", y = NULL,
       caption = "95% intervals clustered by school site. Pre-trend p: joint test that the 2008-2011 event coefficients are zero.")

pdf("../output/event_studies.pdf", width = 11, height = 8.5, onefile = TRUE, useDingbats = FALSE)
print(event_page)
print(did_page)
invisible(dev.off())
