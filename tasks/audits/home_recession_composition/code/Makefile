include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/composition.rds ../output/model_checks.rds ../output/recession_composition.pdf ../output/median_spike.png ../output/recession_evidence.png ../output/reference_years.png ../output/site_sales.rds ../output/site_sales.png ../output/site_sales.pdf

../output/context_snapshot.tar.gz: download_context.R | ../output ../temp
	$(RSCRIPT) $<

../output/composition.rds: measure_composition.R ../input/assessments.rds ../input/overview.rds ../input/distress.rds ../input/raw_sales.csv ../output/context_snapshot.tar.gz ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report ../temp
	$(RSCRIPT) $<

../output/model_checks.rds: estimate_checks.R ../output/composition.rds ../input/assessments.rds ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../output/recession_composition.pdf ../output/median_spike.png ../output/recession_evidence.png ../output/reference_years.png: plot_composition.R ../output/composition.rds ../output/model_checks.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../output/site_sales.rds ../output/site_sales.png ../output/site_sales.pdf: investigate_site_sales.R ../output/composition.rds ../input/distress.rds ../input/raw_sales.csv ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../report
	$(RSCRIPT) $<

../input/assessments.rds: ../../home_initial_assessment/output/initial_assessment.rds | ../input
	ln -sf $< $@

../input/overview.rds: ../../home_data_overview/output/data_review_0.5_single_family.rds | ../input
	ln -sf $< $@

../input/distress.rds: ../../home_sale_distress/output/distress.rds | ../input
	ln -sf $< $@

../input/raw_sales.csv: ../../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	ln -sf $< $@

link-inputs: ../input/assessments.rds ../input/overview.rds ../input/distress.rds ../input/raw_sales.csv

include ../../../shared/code/generic.make
