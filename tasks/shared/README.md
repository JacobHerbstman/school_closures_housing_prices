# Shared research code

Task Makefiles include `code/shell_functions.make` first and `code/generic.make`
last, using the appropriate relative path. The first defines the R, Python,
and LaTeX commands; the second creates task directories and checks upstream
outputs through their owning Makefiles. The rules support GNU Make 3.81.

`code/report_data.R` supplies the common report body. Producing tasks read their
saved datasets, declare their keys, and own the reports under `report/`.
