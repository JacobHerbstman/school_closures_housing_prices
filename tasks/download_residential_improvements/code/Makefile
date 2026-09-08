include ../../shared/code/shell_functions.make

START_YEAR := 2006
END_YEAR := 2025

all: ../output/residential_improvements_$(START_YEAR)_$(END_YEAR).csv

../output/residential_improvements_$(START_YEAR)_$(END_YEAR).csv: download_residential_improvements.R ../input/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv Makefile ../../shared/code/shell_functions.make | ../output ../temp
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv: ../../build_master_home_transactions/output/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/master_home_transactions_$(START_YEAR)_$(END_YEAR).csv

include ../../shared/code/generic.make
