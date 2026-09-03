START_YEAR := 2006
END_YEAR := 2025

all: ../output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv

../output/parcel_sales_$(START_YEAR)_$(END_YEAR).csv: download_parcel_sales.sh Makefile | ../output
	bash $< $(START_YEAR) $(END_YEAR)

link-inputs:

include ../../generic.make
