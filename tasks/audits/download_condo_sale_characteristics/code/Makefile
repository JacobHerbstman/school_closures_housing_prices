include ../../../shared/code/shell_functions.make

START_YEAR := 2006
END_YEAR := 2025

all: ../output/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv

../output/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv: download_condo_sale_characteristics.R ../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output ../temp
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv: ../../../download_parcel_sales/output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv

include ../../../shared/code/generic.make
