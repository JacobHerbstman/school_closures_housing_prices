include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/quarterly_weights.rds ../output/quarterly_weights.pdf ../output/quarterly_events.png ../output/annual_weights.png ../output/quarterly_raw.png

../output/quarterly_weights.rds: estimate_checks.R timeline.csv ../input/price_scales.rds ../input/overview.rds ../input/corrected_sales.csv ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../output/quarterly_weights.pdf ../output/quarterly_events.png ../output/annual_weights.png ../output/quarterly_raw.png: plot_checks.R ../output/quarterly_weights.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../input/price_scales.rds: ../../home_price_scale_checks/output/scale_checks.rds | ../input
	ln -sf $< $@

../input/overview.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	ln -sf $< $@

../input/corrected_sales.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	ln -sf $< $@

link-inputs: ../input/price_scales.rds ../input/overview.rds ../input/corrected_sales.csv

include ../../../shared/code/generic.make
