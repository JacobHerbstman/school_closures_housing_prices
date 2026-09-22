include ../../shared/code/shell_functions.make

all: ../output/home_sales_with_characteristics_2006_2025.csv

../output/home_sales_with_characteristics_2006_2025.csv: build_home_sale_characteristics.R \
	../input/master_home_transactions_2006_2025.csv ../input/residential_improvements_2006_2025.csv \
	Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/master_home_transactions_2006_2025.csv: ../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/residential_improvements_2006_2025.csv: ../../download_residential_improvements/output/residential_improvements_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_2006_2025.csv ../input/residential_improvements_2006_2025.csv

include ../../shared/code/generic.make
