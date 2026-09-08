include ../../shared/code/shell_functions.make

START_YEAR := 2006
END_YEAR := 2025

all: ../output/historical_sale_coordinates_$(START_YEAR)_$(END_YEAR).csv

../output/historical_sale_coordinates_$(START_YEAR)_$(END_YEAR).csv: download_historical_sale_coordinates.R ../input/master_home_transactions_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../output ../temp
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/master_home_transactions_2006_2025.csv: ../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_2006_2025.csv

include ../../shared/code/generic.make
