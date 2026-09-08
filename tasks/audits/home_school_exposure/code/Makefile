include ../../../shared/code/shell_functions.make

# One script produces several outputs; serialize this task on GNU Make 3.81.
.NOTPARALLEL:

all: ../report/saved_tables.txt \
	../output/exposure_summary.csv \
	../output/treatment_control_summary.csv \
	../output/annual_real_price_summary.csv \
	../output/real_price_trends.png \
	../output/annual_residualized_real_price_summary.csv \
	../output/residualized_real_price_trends.png \
	../output/subannual_residualized_real_price_summary.csv \
	../output/subannual_residualized_real_price_trends.png \
	../output/school_site_support.csv \
	../output/treated_control_overlap_pairs.csv \
	../output/competing_exposure.csv \
	../output/radius_sensitivity.csv \
	../output/home_school_exposure_map.png

../output/exposure_summary.csv \
../output/treatment_control_summary.csv \
../output/annual_real_price_summary.csv \
../output/real_price_trends.png \
../output/annual_residualized_real_price_summary.csv \
../output/residualized_real_price_trends.png \
../output/subannual_residualized_real_price_summary.csv \
../output/subannual_residualized_real_price_trends.png \
../output/school_site_support.csv \
../output/treated_control_overlap_pairs.csv \
../output/competing_exposure.csv \
../output/radius_sensitivity.csv \
../output/home_school_exposure_map.png: audit_home_school_exposure.R \
	../input/home_sales_2008_2018.csv \
	../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/Elementary_Closure_SY1213_Chicago_Clean.csv \
	../input/home_school_distances_2006_2025.parquet \
	../input/home_school_exposure_2006_2025.parquet \
	../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/saved_tables.txt: report_saved_tables.R ../../../shared/code/report_data.R \
	../output/exposure_summary.csv \
	../output/treatment_control_summary.csv \
	../output/annual_real_price_summary.csv \
	../output/annual_residualized_real_price_summary.csv \
	../output/subannual_residualized_real_price_summary.csv \
	../output/school_site_support.csv \
	../output/treated_control_overlap_pairs.csv \
	../output/competing_exposure.csv \
	../output/radius_sensitivity.csv \
	Makefile ../../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: \
	../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master_home_transactions_2006_2025.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/Elementary_Closure_SY1213_Chicago_Clean.csv: \
	../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_distances_2006_2025.parquet: \
	../../../calculate_home_school_distances/output/home_school_distances_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: \
	../input/home_sales_2008_2018.csv \
	../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/Elementary_Closure_SY1213_Chicago_Clean.csv \
	../input/home_school_distances_2006_2025.parquet \
	../input/home_school_exposure_2006_2025.parquet

include ../../../shared/code/generic.make
