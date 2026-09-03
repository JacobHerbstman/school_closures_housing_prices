all: ../output/finalization.md ../output/sample_comparison.png

../output/finalization.md: report_finalization.R ../output/sample_reconciliation.rds Makefile | ../output
	Rscript $<

../output/sample_comparison.png: plot_sample_comparison.R ../output/sample_reconciliation.rds Makefile | ../output
	Rscript $<

../output/sample_reconciliation.rds: reconcile_samples.R ../output/class_followups.rds ../input/corrected_home_sale_characteristics_2006_2025.csv ../input/home_sales_with_characteristics_2006_2025.csv ../input/careful_characteristic_updates.rds ../input/home_sales_2008_2018.csv ../input/geocoded_home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv Makefile | ../output
	Rscript $<

../output/class_followups.rds: download_class_followups.R ../input/corrected_home_sale_characteristics_2006_2025.csv ../input/hie_data.parquet Makefile | ../output
	Rscript $<

../input/corrected_home_sale_characteristics_2006_2025.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_with_characteristics_2006_2025.csv: ../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_home_sales_2008_2018.csv: ../../../build_geocoded_home_sales/output/geocoded_home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master_home_transactions_2006_2025.csv: ../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/careful_characteristic_updates.rds: ../../home_improvement_exemptions/output/careful_characteristic_updates.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/hie_data.parquet: ../../../download_home_improvement_exemptions/output/hie_data.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../correct_home_sale_characteristics/code ../output/corrected_home_sale_characteristics_2006_2025.csv

../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../build_home_sale_characteristics/code ../output/home_sales_with_characteristics_2006_2025.csv

../../../clean_home_sales/output/home_sales_2008_2018.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../clean_home_sales/code ../output/home_sales_2008_2018.csv

../../../build_geocoded_home_sales/output/geocoded_home_sales_2008_2018.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../build_geocoded_home_sales/code ../output/geocoded_home_sales_2008_2018.csv

../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../build_geocoded_home_sales/code ../output/geocoded_master_home_transactions_2006_2025.csv

../../../download_home_improvement_exemptions/output/hie_data.parquet: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../download_home_improvement_exemptions/code ../output/hie_data.parquet

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv ../input/home_sales_with_characteristics_2006_2025.csv ../input/home_sales_2008_2018.csv ../input/geocoded_home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv ../input/careful_characteristic_updates.rds ../input/hie_data.parquet

include ../../../generic.make
