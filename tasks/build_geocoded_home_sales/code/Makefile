include ../../shared/code/shell_functions.make

START_YEAR := 2008
END_YEAR := 2018

all: ../output/geocoded_master_home_transactions_2006_2025.csv ../output/geocoded_home_sales_$(START_YEAR)_$(END_YEAR).csv

../output/geocoded_master_home_transactions_2006_2025.csv: geocode_master_transactions.R ../input/master_home_transactions_2006_2025.csv ../input/historical_sale_coordinates_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/geocoded_home_sales_$(START_YEAR)_$(END_YEAR).csv: build_geocoded_home_sales.R ../input/home_sales_$(START_YEAR)_$(END_YEAR).csv ../input/historical_sale_coordinates_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/home_sales_$(START_YEAR)_$(END_YEAR).csv: ../../clean_home_sales/output/home_sales_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/historical_sale_coordinates_2006_2025.csv: ../../download_historical_sale_coordinates/output/historical_sale_coordinates_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/master_home_transactions_2006_2025.csv: ../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_2006_2025.csv ../input/home_sales_$(START_YEAR)_$(END_YEAR).csv ../input/historical_sale_coordinates_2006_2025.csv

include ../../shared/code/generic.make
