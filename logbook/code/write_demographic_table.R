# setwd("/Users/jacobherbstman/Desktop/school_closures_house_prices/logbook/code")
library(data.table)
balance <- fread("../input/demographic_balance.csv")
rows <- balance[geography == "tract" & weighting == "equal_transaction"]
stopifnot(nrow(rows) == 10L, !anyDuplicated(rows$variable))
labels <- c("Median household income (2012 dollars)", "Poverty (percent)", "College graduates, age 25+ (percent)",
            "Non-Hispanic Black (percent)", "Non-Hispanic White (percent)", "Hispanic (percent)",
            "Unemployment (percent)", "Renting (percent)", "Vacancy (percent)", "People per square mile")
lines <- paste(labels, formatC(rows$treated_mean, digits = 1, format = "f", big.mark = ","),
               formatC(rows$control_mean, digits = 1, format = "f", big.mark = ","), sep = " & ")
writeLines(c("\\begin{tabular}{lrr}", "\\hline", "Tract characteristic & Treated & Control \\\\",
             "\\hline", paste0(lines, " \\\\"), "\\hline", "\\end{tabular}"), "../output/demographic_table.tex")
