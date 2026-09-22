include ../../shared/code/shell_functions.make

all: ../output/residential_improvements_2006_2025.csv

../output/residential_improvements_2006_2025.csv: download_residential_improvements.R ../input/master_home_transactions_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../output ../temp
	$(RSCRIPT) $<

../input/master_home_transactions_2006_2025.csv: ../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_2006_2025.csv

include ../../shared/code/generic.make
