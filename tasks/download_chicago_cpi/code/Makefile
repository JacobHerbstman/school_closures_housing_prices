all: ../output/chicago_cpi_all_items.csv

../output/chicago_cpi_all_items.csv: download_chicago_cpi.R Makefile | ../output
	Rscript $<

link-inputs:

include ../../generic.make
