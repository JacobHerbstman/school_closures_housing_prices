include ../../../shared/code/shell_functions.make

# One script produces several outputs; serialize this task on GNU Make 3.81.
.NOTPARALLEL:

all: \
	../output/residential_multicard_pin_years.csv \
	../output/residential_multicard_by_class.csv \
	../output/residential_multicard_improvements.png

../output/residential_multicard_pin_years.csv \
../output/residential_multicard_by_class.csv: audit_residential_multicard_improvements.R \
	../input/residential_improvements_2006_2025.csv ../input/master_home_transactions_2006_2025.csv \
	../input/home_sales_2006_2025.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/residential_multicard_improvements.png: plot_residential_multicard_improvements.R \
	../output/residential_multicard_pin_years.csv ../output/residential_multicard_by_class.csv \
	../input/home_sales_2006_2025.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/residential_improvements_2006_2025.csv: \
	../../../download_residential_improvements/output/residential_improvements_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/master_home_transactions_2006_2025.csv: \
	../../../build_master_home_transactions/output/master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_sales_2006_2025.csv: ../../build_all_home_sales_with_condos/output/home_sales_2006_2025.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/residential_improvements_2006_2025.csv ../input/master_home_transactions_2006_2025.csv \
	../input/home_sales_2006_2025.csv

include ../../../shared/code/generic.make
