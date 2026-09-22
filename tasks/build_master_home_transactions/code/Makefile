include ../../shared/code/shell_functions.make

all: ../output/master_home_transactions_2006_2025.csv

../output/master_home_transactions_2006_2025.csv: build_master_home_transactions.R ../input/parcel_sales_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/parcel_sales_2006_2025.csv: ../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/parcel_sales_2006_2025.csv

include ../../shared/code/generic.make
