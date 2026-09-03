START_YEAR := 2008
END_YEAR := 2018

all: \
	../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv \
	../output/price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv \
	../output/outlier_review_$(START_YEAR)_$(END_YEAR).csv \
	../output/price_per_sqft_distribution_$(START_YEAR)_$(END_YEAR).png

../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv: audit_home_sales_sample_definition.R ../input/home_sales_with_characteristics_2006_2025.csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../output/price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv: ../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv
	@test -s "$@"

../output/outlier_review_$(START_YEAR)_$(END_YEAR).csv: ../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv
	@test -s "$@"

../output/price_per_sqft_distribution_$(START_YEAR)_$(END_YEAR).png: ../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv
	@test -s "$@"

../input/home_sales_with_characteristics_2006_2025.csv: ../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_with_characteristics_2006_2025.csv

include ../../../generic.make
