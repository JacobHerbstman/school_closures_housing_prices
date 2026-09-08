include ../../shared/code/shell_functions.make

all: ../output/chicago_cpi_all_items.csv

../output/chicago_cpi_all_items.csv: download_chicago_cpi.R Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<


include ../../shared/code/generic.make
