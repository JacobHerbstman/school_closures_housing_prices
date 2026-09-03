START_YEAR := 2006
END_YEAR := 2025

all: ../output/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv

../output/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv: build_master_home_transactions.R ../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv ../../setup_environment/output/R_packages.txt Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv: ../../download_parcel_sales/output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/parcel_sales_$(START_YEAR)_$(END_YEAR).csv

include ../../generic.make
