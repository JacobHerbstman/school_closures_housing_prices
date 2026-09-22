include ../../../shared/code/shell_functions.make

all: ../output/sample_summary.rds ../output/sample_summary.pdf

../output/sample_summary.rds: summarize_sample.R \
	../input/home_sales_2008_2018.csv ../input/exposure.parquet ../input/schools.csv ../../../shared/code/report_data.R Makefile | ../output ../report
	$(RSCRIPT) $<

../output/sample_summary.pdf: plot_sample.R ../output/sample_summary.rds Makefile | ../output
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	ln -sf $< $@

../input/exposure.parquet: ../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	ln -sf $< $@

../input/schools.csv: ../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	ln -sf $< $@

link-inputs: ../input/home_sales_2008_2018.csv ../input/exposure.parquet ../input/schools.csv

include ../../../shared/code/generic.make
