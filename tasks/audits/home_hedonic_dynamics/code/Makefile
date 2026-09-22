include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/hedonic_dynamics.rds ../output/hedonic_dynamics.pdf ../output/pooled_comparisons.png ../output/controls_by_year.png ../output/repeat_sales.png ../output/sample_support.png

../output/hedonic_dynamics.rds: estimate_dynamics.R ../input/price_scales.rds ../input/overview.rds ../input/corrected_sales.csv ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../output/hedonic_dynamics.pdf ../output/pooled_comparisons.png ../output/controls_by_year.png ../output/repeat_sales.png ../output/sample_support.png: plot_dynamics.R ../output/hedonic_dynamics.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../input/price_scales.rds: ../../home_price_scale_checks/output/scale_checks.rds | ../input
	ln -sf $< $@

../input/overview.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	ln -sf $< $@

../input/corrected_sales.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	ln -sf $< $@

link-inputs: ../input/price_scales.rds ../input/overview.rds ../input/corrected_sales.csv

include ../../../shared/code/generic.make
