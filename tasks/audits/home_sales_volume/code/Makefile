include ../../../shared/code/shell_functions.make

all: ../output/volume.rds ../output/volume.pdf

../output/volume.rds: estimate_volume.R ../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet ../input/schools.csv \
	../../../shared/code/report_data.R Makefile | ../output ../report
	$(RSCRIPT) $<

../output/volume.pdf: plot_volume.R ../output/volume.rds Makefile | ../output
	$(RSCRIPT) $<

../input/corrected_home_sale_characteristics_2006_2025.csv: \
	../../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	ln -sf $< $@

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	ln -sf $< $@

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

../input/schools.csv: ../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	ln -sf $< $@

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv ../input/home_sales_2008_2018.csv \
	../input/home_school_exposure_2006_2025.parquet ../input/schools.csv

include ../../../shared/code/generic.make
