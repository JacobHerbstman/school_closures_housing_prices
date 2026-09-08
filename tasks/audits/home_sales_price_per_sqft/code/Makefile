include ../../../shared/code/shell_functions.make

# One script produces several outputs; serialize this task on GNU Make 3.81.
.NOTPARALLEL:

START_YEAR := 2006
END_YEAR := 2025

all: \
	../output/home_sales_price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv \
	../output/home_sales_price_per_sqft_extremes_$(START_YEAR)_$(END_YEAR).csv \
	../output/home_sales_price_per_sqft_$(START_YEAR)_$(END_YEAR).png

../output/home_sales_price_per_sqft_summary_$(START_YEAR)_$(END_YEAR).csv \
../output/home_sales_price_per_sqft_extremes_$(START_YEAR)_$(END_YEAR).csv \
../output/home_sales_price_per_sqft_$(START_YEAR)_$(END_YEAR).png: audit_home_sales_price_per_sqft.R \
	../input/home_sales_$(START_YEAR)_$(END_YEAR).csv \
	../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv \
	../output/sale_improvement_characteristics_$(START_YEAR)_$(END_YEAR).csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../output/sale_improvement_characteristics_$(START_YEAR)_$(END_YEAR).csv: \
	download_sale_improvement_characteristics.R ../input/home_sales_$(START_YEAR)_$(END_YEAR).csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output ../temp
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/home_sales_$(START_YEAR)_$(END_YEAR).csv: \
	../../build_all_home_sales_with_condos/output/home_sales_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv: \
	../../download_condo_sale_characteristics/output/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_$(START_YEAR)_$(END_YEAR).csv \
	../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv

include ../../../shared/code/generic.make
