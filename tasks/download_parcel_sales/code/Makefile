include ../../shared/code/shell_functions.make

all: ../output/parcel_sales_2006_2025.csv

../output/parcel_sales_2006_2025.csv: download_parcel_sales.sh Makefile | ../output
	bash $<

include ../../shared/code/generic.make
