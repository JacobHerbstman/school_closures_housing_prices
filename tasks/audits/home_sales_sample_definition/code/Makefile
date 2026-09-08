include ../../../shared/code/shell_functions.make

# One script produces several outputs; serialize this task on GNU Make 3.81.
.NOTPARALLEL:

START_YEAR := 2008
END_YEAR := 2018

all: \
	../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv \
	../output/price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv \
	../output/outlier_review_$(START_YEAR)_$(END_YEAR).csv \
	../output/price_per_sqft_distribution_$(START_YEAR)_$(END_YEAR).png

../output/sample_attrition_$(START_YEAR)_$(END_YEAR).csv \
../output/price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv \
../output/outlier_review_$(START_YEAR)_$(END_YEAR).csv \
../output/price_per_sqft_distribution_$(START_YEAR)_$(END_YEAR).png: audit_home_sales_sample_definition.R \
	../input/home_sales_with_characteristics_2006_2025.csv ../../../setup_environment/output/R_packages.txt \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/home_sales_with_characteristics_2006_2025.csv: \
	../../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_with_characteristics_2006_2025.csv

include ../../../shared/code/generic.make
