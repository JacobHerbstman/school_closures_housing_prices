all: \
	../output/annual_home_sales_benchmarks.csv \
	../output/monthly_home_sales_benchmarks.csv \
	../output/home_sales_composition_2024.csv \
	../output/home_sales_external_correlations.csv \
	../output/home_sales_external_benchmarks.png \
	../output/home_sales_monthly_benchmarks.png \
	../output/home_sales_descriptive_dashboard.png

../output/external_home_market_benchmarks.csv: download_external_benchmarks.py Makefile | ../output
	python3 $<

../output/annual_home_sales_benchmarks.csv: build_home_sales_benchmarks.R ../input/parcel_sales_2006_2025.csv ../input/home_sales_2006_2025.csv ../output/external_home_market_benchmarks.csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $<

../output/home_sales_composition_2024.csv: ../output/annual_home_sales_benchmarks.csv
	@test -s "$@"

../output/monthly_home_sales_benchmarks.csv: ../output/annual_home_sales_benchmarks.csv
	@test -s "$@"

../output/home_sales_external_correlations.csv: ../output/annual_home_sales_benchmarks.csv
	@test -s "$@"

../output/home_sales_external_benchmarks.png: plot_home_sales_benchmarks.R ../output/annual_home_sales_benchmarks.csv ../output/home_sales_composition_2024.csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $<

../output/home_sales_monthly_benchmarks.png: plot_home_sales_monthly_benchmarks.R ../output/monthly_home_sales_benchmarks.csv ../output/home_sales_external_correlations.csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $<

../output/home_sales_descriptive_dashboard.png: plot_home_sales_descriptive_dashboard.R ../output/annual_home_sales_benchmarks.csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $<

../input/parcel_sales_2006_2025.csv: ../../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2006_2025.csv: ../../build_all_home_sales_with_condos/output/home_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../../../download_parcel_sales/output/parcel_sales_2006_2025.csv:
	$(MAKE) -C ../../../download_parcel_sales/code ../output/parcel_sales_2006_2025.csv

../../build_all_home_sales_with_condos/output/home_sales_2006_2025.csv:
	$(MAKE) -C ../../build_all_home_sales_with_condos/code ../output/home_sales_2006_2025.csv

../../../setup_environment/output/R_packages.txt:
	$(MAKE) -C ../../../setup_environment/code ../output/R_packages.txt

link-inputs: ../input/parcel_sales_2006_2025.csv ../input/home_sales_2006_2025.csv

include ../../../generic.make
