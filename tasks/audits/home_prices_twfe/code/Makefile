include ../../../shared/code/shell_functions.make

# The estimation script writes five tables; serialize on GNU Make 3.81.
.NOTPARALLEL:

all: ../report/saved_tables.txt ../output/coefficients.csv ../output/model_summary.csv ../output/site_year_support.csv \
	../output/raw_price_trends.csv ../output/site_period_support.csv \
	../output/event_studies.png ../output/event_studies_semiannual.png ../output/event_studies_amenities.png \
	../output/raw_prices_annual.png ../output/raw_prices_semiannual.png \
	../output/event_studies_weights_annual.png ../output/event_studies_weights_semiannual.png \
	../output/event_studies_weights_amenities.png

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

link-inputs: ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/home_amenity_distances.csv

include ../../../shared/code/generic.make
