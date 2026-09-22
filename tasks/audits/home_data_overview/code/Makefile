include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

radii := 0.125 0.5

all: ../output/data_overview_0.5_single_family.pdf ../output/data_review_0.5_single_family.md ../report/data_review_0.5_single_family.txt ../output/data_overview_single_family.pdf ../output/data_review_single_family.md ../report/data_review_single_family.txt ../output/data_overview_through_2023.pdf ../output/data_review_through_2023.md ../report/data_review_through_2023.txt \
	../output/sales_by_pre_price.png ../output/sales_by_pre_price.pdf ../output/late_decline.rds ../report/late_decline.txt ../output/late_decline.pdf $(foreach radius,$(radii),../output/data_overview_$(radius).pdf ../output/data_review_$(radius).md ../report/data_review_$(radius).txt ../output/data_review_$(radius).rds ../output/school_map_$(radius).png ../output/price_trends_$(radius).png ../output/price_distribution_$(radius).png ../output/sales_counts_$(radius).png ../output/property_mix_$(radius).png ../output/site_support_$(radius).png ../output/selection_$(radius).png ../output/complete_characteristics_price_trends_$(radius).png) \
	 ../output/complete_characteristics_price_trends.png ../output/data_overview.pdf ../output/data_review.md ../report/data_review.txt \
	../output/school_map.png ../output/price_trends.png ../output/price_distribution.png \
	../output/sales_counts.png ../output/property_mix.png ../output/site_support.png \
	../output/selection.png


../output/complete_characteristics_price_trends_0.5_single_family.png ../output/data_overview_0.5_single_family.pdf ../output/school_map_0.5_single_family.png \
	../output/price_trends_0.5_single_family.png ../output/price_distribution_0.5_single_family.png ../output/sales_counts_0.5_single_family.png \
	../output/property_mix_0.5_single_family.png ../output/site_support_0.5_single_family.png ../output/selection_0.5_single_family.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review_0.5_single_family.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< 0.5 2018 single_family

../output/data_review_0.5_single_family.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< 0.5 2018 single_family

../output/data_review_0.5_single_family.md ../report/data_review_0.5_single_family.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review_0.5_single_family.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< 0.5 2018 single_family

../output/complete_characteristics_price_trends_single_family.png ../output/data_overview_single_family.pdf ../output/school_map_single_family.png \
	../output/price_trends_single_family.png ../output/price_distribution_single_family.png ../output/sales_counts_single_family.png \
	../output/property_mix_single_family.png ../output/site_support_single_family.png ../output/selection_single_family.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review_single_family.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< 0.25 2018 single_family

../output/data_review_single_family.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< 0.25 2018 single_family

../output/data_review_single_family.md ../report/data_review_single_family.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review_single_family.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< 0.25 2018 single_family

../output/complete_characteristics_price_trends_through_2023.png ../output/data_overview_through_2023.pdf ../output/school_map_through_2023.png \
	../output/price_trends_through_2023.png ../output/price_distribution_through_2023.png ../output/sales_counts_through_2023.png \
	../output/property_mix_through_2023.png ../output/site_support_through_2023.png ../output/selection_through_2023.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review_through_2023.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< 0.25 2023 all

../output/data_review_through_2023.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< 0.25 2023 all

../output/data_review_through_2023.md ../report/data_review_through_2023.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review_through_2023.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< 0.25 2023 all

../output/sales_by_pre_price.png ../output/sales_by_pre_price.pdf: plot_pre_price_sales.R ../output/late_decline.rds \
	../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/late_decline.rds: investigate_decline.R ../output/data_review.rds ../input/corrected_sales.csv \
	../input/exposure.parquet ../input/cpi.csv ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/late_decline.txt ../output/late_decline.pdf: present_decline.R ../output/late_decline.rds \
	../../../shared/code/report_data.R ../../../shared/code/shell_functions.make | ../report ../output
	$(RSCRIPT) $<

../output/complete_characteristics_price_trends.png ../output/data_overview.pdf ../output/school_map.png \
	../output/price_trends.png ../output/price_distribution.png ../output/sales_counts.png \
	../output/property_mix.png ../output/site_support.png ../output/selection.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< 0.25 2018 all

../output/data_review.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< 0.25 2018 all

../output/data_review.md ../report/data_review.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< 0.25 2018 all

../output/complete_characteristics_price_trends_%.png ../output/data_overview_%.pdf ../output/school_map_%.png \
	../output/price_trends_%.png ../output/price_distribution_%.png ../output/sales_counts_%.png \
	../output/property_mix_%.png ../output/site_support_%.png ../output/selection_%.png: plot_overview.R \
	../input/chicago_hydro.geojson ../output/data_review_%.rds ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< $* 2018 all

../output/data_review_%.rds: review_data.R school_reference.csv candidate_reference.csv ../input/schools.csv \
	../input/closure_roster.csv ../input/consortium_school_closings_2015.pdf ../input/cps_february_2013_list.pdf \
	../input/fermi_south_shore_2013.pdf ../input/garfield_faraday_2013.pdf ../input/corrected_sales.csv \
	../input/clean_sales.csv ../input/geocoded_master.csv ../input/exposure.parquet ../input/cpi.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< $* 2018 all

../output/data_review_%.md ../report/data_review_%.txt: report_review.R ../../../shared/code/report_data.R \
	../output/data_review_%.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< $* 2018 all

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

../input/clean_sales.csv: ../../../clean_home_sales/output/home_sales_2008_2023.csv | ../input
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
