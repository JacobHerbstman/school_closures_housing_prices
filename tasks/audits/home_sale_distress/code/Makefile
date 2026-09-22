include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/distress.rds ../output/distress.pdf ../output/seller_proxies.png ../output/coverage_and_deeds.png ../output/before_price_screens.png

../output/distress.rds: measure_distress.R seller_patterns.csv ../input/raw_sales.csv ../input/corrected_sales.csv ../input/exposure.parquet ../input/overview.rds ../output/sales_metadata.json ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../output/distress.pdf ../output/seller_proxies.png ../output/coverage_and_deeds.png ../output/before_price_screens.png: plot_distress.R ../output/distress.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../output/sales_metadata.json: | ../output
	curl --fail --silent --show-error --retry 3 --max-time 60 -o $@.part 'https://datacatalog.cookcountyil.gov/api/views/wvhk-k5uv.json'
	python3 -c 'import json; x=json.load(open("$@.part")); assert x["id"] == "wvhk-k5uv" and len(x["columns"]) > 0'
	mv $@.part $@

../input/raw_sales.csv: ../../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	ln -sf $< $@

../input/corrected_sales.csv: ../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	ln -sf $< $@

../input/exposure.parquet: ../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

../input/overview.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	ln -sf $< $@

link-inputs: ../input/raw_sales.csv ../input/corrected_sales.csv ../input/exposure.parquet ../input/overview.rds

include ../../../shared/code/generic.make
