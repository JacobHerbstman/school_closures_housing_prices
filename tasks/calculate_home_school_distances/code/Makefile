include ../../shared/code/shell_functions.make

all: ../output/home_school_distances_2006_2025.parquet

../output/home_school_distances_2006_2025.parquet: calculate_home_school_distances.R \
	../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/Elementary_Closure_SY1213_Chicago_Clean.csv \
	Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/geocoded_master_home_transactions_2006_2025.csv: ../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/Elementary_Closure_SY1213_Chicago_Clean.csv: ../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/Elementary_Closure_SY1213_Chicago_Clean.csv

include ../../shared/code/generic.make
