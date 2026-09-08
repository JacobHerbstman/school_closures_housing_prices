include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/complete_characteristics_price_trends.png ../output/data_overview.pdf ../output/data_review.md ../report/data_review.txt \
	../output/school_map.png ../output/price_trends.png ../output/price_distribution.png \
	../output/sales_counts.png ../output/property_mix.png ../output/site_support.png \
	../output/selection.png

../output/complete_characteristics_price_trends.png ../output/data_overview.pdf ../output/school_map.png \
	../output/price_trends.png ../output/price_distribution.png ../output/sales_counts.png \
	../output/property_mix.png ../output/site_support.png ../output/selection.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/data_review.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $<

../output/data_review.md ../report/data_review.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $<

../input/schools.csv: ../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/closure_roster.csv: ../../../raw_school_data/output/Elementary_Closure_SY1213_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/consortium_school_closings_2015.pdf: \
	../../../raw_school_data/output/consortium_school_closings_2015.pdf | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/corrected_sales.csv: \
	../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/clean_sales.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/exposure.parquet: ../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/cpi.csv: ../../../download_chicago_cpi/output/chicago_cpi_all_items.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/cps_february_2013_list.pdf: ../../../raw_school_data/output/cps_february_2013_list.pdf | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/fermi_south_shore_2013.pdf: ../../../raw_school_data/output/fermi_south_shore_2013.pdf | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/garfield_faraday_2013.pdf: ../../../raw_school_data/output/garfield_faraday_2013.pdf | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/chicago_hydro.geojson: ../../download_baseline_amenities/output/chicago_hydro.geojson | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/chicago_hydro.geojson ../input/schools.csv ../input/closure_roster.csv \
	../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv

include ../../../shared/code/generic.make
