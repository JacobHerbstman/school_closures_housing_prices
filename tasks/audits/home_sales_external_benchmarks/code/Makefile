include ../../../shared/code/shell_functions.make

# One script produces several outputs; serialize this task on GNU Make 3.81.
.NOTPARALLEL:

all: \
	../output/noncondo_monthly_benchmarks.csv \
	../output/noncondo_external_correlations.csv \
	../output/noncondo_acs_comparison.csv \
	../output/noncondo_external_benchmarks.png \
	../output/annual_home_sales_benchmarks.csv \
	../output/monthly_home_sales_benchmarks.csv \
	../output/home_sales_composition_2024.csv \
	../output/home_sales_external_correlations.csv \
	../output/home_sales_external_benchmarks.png \
	../output/home_sales_monthly_benchmarks.png \
	../output/home_sales_descriptive_dashboard.png

../output/annual_home_sales_benchmarks.csv \
../output/home_sales_composition_2024.csv \
../output/monthly_home_sales_benchmarks.csv \
../output/home_sales_external_correlations.csv: build_home_sales_benchmarks.R \
	../input/parcel_sales_2006_2025.csv ../input/home_sales_2006_2025.csv \
	../output/external_home_market_benchmarks.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $<

../output/noncondo_monthly_benchmarks.csv \
../output/noncondo_external_correlations.csv \
../output/noncondo_acs_comparison.csv \
../output/noncondo_external_benchmarks.png: compare_noncondo_sales.R \
	../input/corrected_home_sale_characteristics_2006_2025.csv ../input/home_sales_2008_2018.csv \
	../output/external_home_market_benchmarks.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $<

../output/external_home_market_benchmarks.csv: download_external_benchmarks.py Makefile ../../../shared/code/shell_functions.make | ../output
	$(PYTHON) $<

../output/home_sales_external_benchmarks.png: plot_home_sales_benchmarks.R \
	../output/annual_home_sales_benchmarks.csv ../output/home_sales_composition_2024.csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/home_sales_monthly_benchmarks.png: plot_home_sales_monthly_benchmarks.R \
	../output/monthly_home_sales_benchmarks.csv ../output/home_sales_external_correlations.csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/home_sales_descriptive_dashboard.png: plot_home_sales_descriptive_dashboard.R \
	../output/annual_home_sales_benchmarks.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $<

../input/parcel_sales_2006_2025.csv: ../../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2006_2025.csv: ../../build_all_home_sales_with_condos/output/home_sales_2006_2025.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/corrected_home_sale_characteristics_2006_2025.csv: \
	../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv ../input/home_sales_2008_2018.csv \
	../input/parcel_sales_2006_2025.csv ../input/home_sales_2006_2025.csv

include ../../../shared/code/generic.make
