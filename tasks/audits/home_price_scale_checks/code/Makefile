include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/scale_checks.rds ../output/scale_checks.pdf ../output/ppml_events.png ../output/predicted_gaps.png ../output/predicted_levels_events.png

../output/scale_checks.rds: check_price_scales.R ../input/overview.rds ../input/corrected_sales.csv ../input/cpi.csv ../input/exposure.parquet ../input/original_events.rds ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../output/scale_checks.pdf ../output/ppml_events.png ../output/predicted_gaps.png ../output/predicted_levels_events.png: plot_scale_checks.R ../output/scale_checks.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../input/overview.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	ln -sf $< $@

../input/corrected_sales.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	ln -sf $< $@

../input/cpi.csv: ../../../download_chicago_cpi/output/chicago_cpi_all_items.csv | ../input
	ln -sf $< $@

../input/exposure.parquet: ../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

../input/original_events.rds: ../../home_prices_twfe/output/single_family_events_0.5.rds | ../input
	ln -sf $< $@

link-inputs: ../input/overview.rds ../input/corrected_sales.csv ../input/cpi.csv ../input/exposure.parquet ../input/original_events.rds

include ../../../shared/code/generic.make
