all: ../output/careful_validation.md

../output/careful_validation.md: validate_careful_corrections.R ../output/validation.md ../output/careful_characteristic_updates.rds ../output/post_expiry_records.rds ../output/characteristic_updates.rds ../output/exemption_years.rds ../input/home_sales_with_characteristics_2006_2025.csv Makefile | ../output
	Rscript $<

../output/post_expiry_records.rds: download_post_expiry_records.R ../output/careful_characteristic_updates.rds ../output/characteristic_updates.rds Makefile | ../output
	Rscript $<

../output/careful_characteristic_updates.rds: apply_careful_corrections.R load_ccao_reference.R ../output/characteristic_updates.rds ../output/linked_transactions.rds ../output/exemption_years.rds ../input/legacy_improvement_metadata.json ../input/ccao.zip Makefile | ../output
	Rscript $<

../output/validation.md: validate_exemption_corrections.R load_ccao_reference.R ../output/characteristic_updates.rds ../output/linked_transactions.rds ../output/exemption_years.rds ../output/source_inventory.csv Makefile | ../output
	Rscript $<

../output/characteristic_updates.rds: apply_exemption_corrections.R load_ccao_reference.R ../output/linked_transactions.rds ../output/exemption_years.rds Makefile | ../output
	Rscript $<

../output/linked_transactions.rds: link_transaction_exemptions.R ../output/exemption_years.rds ../input/home_sales_with_characteristics_2006_2025.csv Makefile | ../output
	Rscript $<

../output/exemption_years.rds: build_exemption_years.R load_ccao_reference.R ../output/source_inventory.csv Makefile | ../output
	Rscript $<

../output/source_inventory.csv: inspect_exemption_sources.R load_ccao_reference.R source_sha256.csv ../input/hie_data.parquet ../input/ccao.zip ../input/model_ingest.json ../input/improvement_metadata.json ../input/home_sales_with_characteristics_2006_2025.csv Makefile | ../output
	Rscript $<

../input/hie_data.parquet: ../../../../data_raw/home_improvement_exemptions/hie_data.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ccao.zip: ../../../../data_raw/home_improvement_exemptions/ccao.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/model_ingest.json: ../../../../data_raw/home_improvement_exemptions/model_ingest.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/improvement_metadata.json: ../../../../data_raw/home_improvement_exemptions/improvement_metadata.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/legacy_improvement_metadata.json: ../../../../data_raw/home_improvement_exemptions/legacy_improvement_metadata.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_with_characteristics_2006_2025.csv: ../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../build_home_sale_characteristics/code ../output/home_sales_with_characteristics_2006_2025.csv

../../../../data_raw/home_improvement_exemptions:
	mkdir -p $@

../../../../data_raw/home_improvement_exemptions/hie_data.parquet: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../download_home_improvement_exemptions/code ../output/hie_data.parquet

../../../../data_raw/home_improvement_exemptions/ccao.zip: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../download_home_improvement_exemptions/code ../output/ccao.zip

../../../../data_raw/home_improvement_exemptions/model_ingest.json: | ../../../../data_raw/home_improvement_exemptions
	curl --fail --location --show-error --max-time 120 'https://api.github.com/repos/ccao-data/model-res-avm/contents/pipeline/00-ingest.R?ref=ced8ac3bb83ba0535cd10910f9eadec89962e937' -o $@.tmp
	mv $@.tmp $@

../../../../data_raw/home_improvement_exemptions/improvement_metadata.json: | ../../../../data_raw/home_improvement_exemptions
	curl --fail --location --show-error --max-time 120 'https://datacatalog.cookcountyil.gov/api/views/x54s-btds' -o $@.tmp
	mv $@.tmp $@

../../../../data_raw/home_improvement_exemptions/legacy_improvement_metadata.json: FORCE_UPSTREAM_CHECK
	$(MAKE) -C ../../../download_home_improvement_exemptions/code ../output/legacy_improvement_metadata.json

link-inputs: ../input/hie_data.parquet ../input/ccao.zip ../input/model_ingest.json ../input/improvement_metadata.json ../input/legacy_improvement_metadata.json ../input/home_sales_with_characteristics_2006_2025.csv

include ../../../generic.make
