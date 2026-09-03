START_YEAR := 2006
END_YEAR := 2025

all: ../output/home_sales_$(START_YEAR)_$(END_YEAR).csv

../output/home_sales_$(START_YEAR)_$(END_YEAR).csv: clean_home_sales.R ../input/home_sales_with_characteristics_$(START_YEAR)_$(END_YEAR).csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../output/home_sales_with_characteristics_$(START_YEAR)_$(END_YEAR).csv: build_home_sale_characteristics.R ../input/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv ../input/residential_improvements_$(START_YEAR)_$(END_YEAR).csv ../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../output/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv: build_master_home_transactions.R ../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv ../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv ../../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../input/home_sales_with_characteristics_$(START_YEAR)_$(END_YEAR).csv: ../output/home_sales_with_characteristics_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv: ../output/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv: ../../../download_parcel_sales/output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/residential_improvements_$(START_YEAR)_$(END_YEAR).csv: ../../../download_residential_improvements/output/residential_improvements_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv: ../../download_condo_sale_characteristics/output/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../../../download_parcel_sales/output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv:
	$(MAKE) -C ../../../download_parcel_sales/code

../../../download_residential_improvements/output/residential_improvements_$(START_YEAR)_$(END_YEAR).csv:
	$(MAKE) -C ../../../download_residential_improvements/code

../../download_condo_sale_characteristics/output/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv:
	$(MAKE) -C ../../download_condo_sale_characteristics/code

../../../setup_environment/output/R_packages.txt:
	$(MAKE) -C ../../../setup_environment/code

link-inputs: \
	../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv \
	../input/residential_improvements_$(START_YEAR)_$(END_YEAR).csv \
	../input/condo_sale_characteristics_$(START_YEAR)_$(END_YEAR).csv

include ../../../generic.make
