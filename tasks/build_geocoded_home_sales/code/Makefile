include ../../shared/code/shell_functions.make

all: ../output/geocoded_master_home_transactions_2006_2025.csv

../output/geocoded_master_home_transactions_2006_2025.csv: geocode_master_transactions.R \
	../input/master_home_transactions_2006_2025.csv ../input/historical_sale_coordinates_2006_2025.csv \
	Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/historical_sale_coordinates_2006_2025.csv: ../../download_historical_sale_coordinates/output/historical_sale_coordinates_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/master_home_transactions_2006_2025.csv: ../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_2006_2025.csv ../input/historical_sale_coordinates_2006_2025.csv

include ../../shared/code/generic.make
