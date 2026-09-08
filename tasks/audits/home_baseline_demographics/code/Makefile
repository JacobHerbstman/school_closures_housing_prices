include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../report/saved_tables.txt ../output/baseline_demographics.csv ../output/home_census_geographies.csv \
	../report/baseline_demographics.txt ../report/home_census_geographies.txt ../output/demographic_balance.csv \
	../output/demographic_balance.png

../output/baseline_demographics.csv ../output/home_census_geographies.csv ../report/baseline_demographics.txt \
	../report/home_census_geographies.txt: build_baseline_demographics.R ../input/home_sales_2008_2018.csv \
	../input/geocoded_master_home_transactions_2006_2025.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/g20125il.csv ../input/sequence_lookup.txt ../input/tl_2012_17_tract.zip ../input/tl_2012_17_bg.zip \
	../input/20125il0005000.zip ../input/20125il0043000.zip ../input/20125il0049000.zip \
	../input/20125il0058000.zip ../input/20125il0078000.zip ../input/20125il0102000.zip \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $<

../output/demographic_balance.csv ../output/demographic_balance.png: compare_demographics.R \
	../output/baseline_demographics.csv ../output/home_census_geographies.csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/saved_tables.txt: report_saved_tables.R ../../../shared/code/report_data.R \
	../output/demographic_balance.csv \
	Makefile ../../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master_home_transactions_2006_2025.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/g20125il.csv: ../../download_baseline_demographics/output/g20125il.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/sequence_lookup.txt: ../../download_baseline_demographics/output/sequence_lookup.txt | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/tl_2012_17_tract.zip: ../../download_baseline_demographics/output/tl_2012_17_tract.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/tl_2012_17_bg.zip: ../../download_baseline_demographics/output/tl_2012_17_bg.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0005000.zip: ../../download_baseline_demographics/output/20125il0005000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0043000.zip: ../../download_baseline_demographics/output/20125il0043000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0049000.zip: ../../download_baseline_demographics/output/20125il0049000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0058000.zip: ../../download_baseline_demographics/output/20125il0058000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0078000.zip: ../../download_baseline_demographics/output/20125il0078000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/20125il0102000.zip: ../../download_baseline_demographics/output/20125il0102000.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/home_school_exposure_2006_2025.parquet ../input/g20125il.csv ../input/sequence_lookup.txt \
	../input/tl_2012_17_tract.zip ../input/tl_2012_17_bg.zip ../input/20125il0005000.zip \
	../input/20125il0043000.zip ../input/20125il0049000.zip ../input/20125il0058000.zip \
	../input/20125il0078000.zip ../input/20125il0102000.zip

include ../../../shared/code/generic.make
