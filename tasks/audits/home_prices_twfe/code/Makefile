include ../../../shared/code/shell_functions.make

all: ../output/twfe.rds ../output/event_studies.pdf

../output/twfe.rds: estimate_twfe.R ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../../../shared/code/report_data.R Makefile | ../output ../report
	$(RSCRIPT) $<

../output/event_studies.pdf: plot_event_studies.R ../output/twfe.rds Makefile | ../output
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	ln -sf $< $@

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

link-inputs: ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet

include ../../../shared/code/generic.make
