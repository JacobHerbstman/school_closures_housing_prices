include ../../../shared/code/shell_functions.make

all: ../output/finalization.md ../output/sample_comparison.png

../output/finalization.md: report_finalization.R ../output/sample_reconciliation.rds Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/sample_comparison.png: plot_sample_comparison.R ../output/sample_reconciliation.rds Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/sample_reconciliation.rds: reconcile_samples.R ../output/class_followups.rds \
	../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/home_sales_with_characteristics_2006_2025.csv ../input/careful_characteristic_updates.rds \
	../input/home_sales_2008_2018.csv ../input/geocoded_home_sales_2008_2018.csv \
	../input/geocoded_master_home_transactions_2006_2025.csv Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/class_followups.rds: download_class_followups.R \
	../input/corrected_home_sale_characteristics_2006_2025.csv ../input/hie_data.parquet Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/corrected_home_sale_characteristics_2006_2025.csv: \
	../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_with_characteristics_2006_2025.csv: \
	../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_home_sales_2008_2018.csv: \
	../../../build_geocoded_home_sales/output/geocoded_home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master_home_transactions_2006_2025.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/careful_characteristic_updates.rds: \
	../../home_improvement_exemptions/output/careful_characteristic_updates.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/hie_data.parquet: ../../../download_home_improvement_exemptions/output/hie_data.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/home_sales_with_characteristics_2006_2025.csv ../input/home_sales_2008_2018.csv \
	../input/geocoded_home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/careful_characteristic_updates.rds ../input/hie_data.parquet

include ../../../shared/code/generic.make
