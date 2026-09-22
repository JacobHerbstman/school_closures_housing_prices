include ../../../shared/code/shell_functions.make

# The estimation script writes five tables; serialize on GNU Make 3.81.
.NOTPARALLEL:

all: ../output/event_studies_single_family_0.5.pdf ../output/event_studies_single_family_0.5.png ../report/single_family_events_0.5.txt ../output/event_studies_single_family.pdf ../output/event_studies_single_family.png ../report/single_family_events.txt ../output/event_studies_through_2023.png ../output/event_studies_through_2023.pdf ../report/long_events.txt ../report/saved_tables.txt ../output/coefficients.csv ../output/model_summary.csv ../output/site_year_support.csv \
	../output/raw_price_trends.csv ../output/site_period_support.csv \
	../output/event_studies.png ../output/event_studies_semiannual.png ../output/event_studies_amenities.png \
	../output/raw_prices_annual.png ../output/raw_prices_semiannual.png \
	../output/event_studies_weights_annual.png ../output/event_studies_weights_semiannual.png \
	../output/event_studies_weights_amenities.png

../output/single_family_events_0.5.rds: estimate_long_events.R ../input/overview_single_family_0.5.rds ../input/corrected_sales.csv \
	../input/cpi.csv ../input/home_school_exposure_2006_2025.parquet \
	../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< single_family 0.5

../output/event_studies_single_family_0.5.png ../output/event_studies_single_family_0.5.pdf ../report/single_family_events_0.5.txt: \
	present_long_events.R ../output/single_family_events_0.5.rds ../../../shared/code/report_data.R \
	../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< single_family 0.5

../output/single_family_events.rds: estimate_long_events.R ../input/overview_single_family.rds ../input/corrected_sales.csv \
	../input/cpi.csv ../input/home_school_exposure_2006_2025.parquet \
	../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< single_family 0.25

../output/event_studies_single_family.png ../output/event_studies_single_family.pdf ../report/single_family_events.txt: \
	present_long_events.R ../output/single_family_events.rds ../../../shared/code/report_data.R \
	../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< single_family 0.25

../output/long_events.rds: estimate_long_events.R ../input/overview_through_2023.rds ../input/corrected_sales.csv \
	../input/cpi.csv ../input/home_school_exposure_2006_2025.parquet ../output/coefficients.csv \
	../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< all 0.25

../output/event_studies_through_2023.png ../output/event_studies_through_2023.pdf ../report/long_events.txt: \
	present_long_events.R ../output/long_events.rds ../../../shared/code/report_data.R \
	../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< all 0.25

../output/coefficients.csv ../output/model_summary.csv ../output/site_year_support.csv \
	../output/raw_price_trends.csv ../output/site_period_support.csv: estimate_twfe.R \
	../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/home_amenity_distances.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/raw_prices_annual.png ../output/raw_prices_semiannual.png ../output/event_studies_weights_annual.png \
	../output/event_studies_weights_semiannual.png ../output/event_studies_weights_amenities.png: \
	plot_weight_comparisons.R ../output/raw_price_trends.csv ../output/coefficients.csv \
	../output/model_summary.csv Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/event_studies.png ../output/event_studies_semiannual.png ../output/event_studies_amenities.png: \
	plot_event_studies.R ../output/coefficients.csv ../output/model_summary.csv Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/saved_tables.txt: report_saved_tables.R ../../../shared/code/report_data.R \
	../output/coefficients.csv \
	../output/model_summary.csv \
	../output/site_year_support.csv \
	../output/raw_price_trends.csv \
	../output/site_period_support.csv \
	Makefile ../../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_amenity_distances.csv: ../../home_amenity_distances/output/home_amenity_distances.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_through_2023.rds: ../../home_data_overview/output/data_review_through_2023.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/corrected_sales.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/cpi.csv: ../../../download_chicago_cpi/output/chicago_cpi_all_items.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_single_family.rds: ../../home_data_overview/output/data_review_single_family.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_single_family_0.5.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/overview_single_family_0.5.rds ../input/overview_single_family.rds ../input/overview_through_2023.rds ../input/corrected_sales.csv ../input/cpi.csv ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/home_amenity_distances.csv

include ../../../shared/code/generic.make
