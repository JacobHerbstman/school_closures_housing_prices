include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/sale_flags.md ../output/sale_flags_table.tex ../report/sale_flags.txt

../output/sale_flags.rds: audit_flags.R ../input/raw_sales.csv ../input/master.csv ../input/corrected.csv \
	../input/exposure.parquet ../input/data_review.rds ../output/county_sale.sql Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/sale_flags.md ../output/sale_flags_table.tex ../report/sale_flags.txt: report_flags.R \
	../../../shared/code/report_data.R ../output/sale_flags.rds Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $<

../output/county_sale.sql: Makefile | ../output
	wget --quiet --timeout=60 --tries=3 -O ../output/county_sale.sql.part 'https://raw.githubusercontent.com/ccao-data/data-architecture/1a64383a9a4b1791f4aa5ecc71841f6006184350/dbt/models/default/default.vw_pin_sale.sql'
	mv ../output/county_sale.sql.part $@

../input/raw_sales.csv: ../../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/master.csv: ../../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/corrected.csv: \
	../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/exposure.parquet: ../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/data_review.rds: ../../home_data_overview/output/data_review.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/raw_sales.csv ../input/master.csv ../input/corrected.csv ../input/exposure.parquet \
	../input/data_review.rds

include ../../../shared/code/generic.make
