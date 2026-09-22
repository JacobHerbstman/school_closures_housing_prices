include ../../../shared/code/shell_functions.make

all: ../output/twfe.rds ../output/event_studies.pdf

../output/twfe.rds: estimate_twfe.R ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/schools.csv ../input/sale_tract_change.csv ../../../shared/code/report_data.R Makefile | ../output ../report
	$(RSCRIPT) $<

../output/event_studies.pdf: plot_event_studies.R ../output/twfe.rds Makefile | ../output
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	ln -sf $< $@

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

../input/schools.csv: ../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	ln -sf $< $@

../input/sale_tract_change.csv: ../../tract_demographic_change/output/sale_tract_change.csv | ../input
	ln -sf $< $@

link-inputs: ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet ../input/schools.csv \
	../input/sale_tract_change.csv

include ../../../shared/code/generic.make
