include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../report/saved_tables.txt ../output/ring_assignments.parquet ../report/ring_assignments.txt ../output/sample_summary.csv \
	../output/coefficients.csv ../output/model_summary.csv ../output/site_year_support.csv ../output/raw_trends.csv \
	../output/raw_equal_transaction.png ../output/raw_equal_site_year.png \
	../output/event_no_controls.png ../output/event_hedonics.png ../output/event_fixed_effects.png ../output/did_by_ring.png


all: ../output/common_ring_assignments.parquet ../output/common_support.csv ../output/common_sample_summary.csv ../report/common_ring_assignments.txt \
	../output/common_coefficients.csv ../output/common_model_summary.csv ../output/common_site_year_support.csv ../output/common_raw_trends.csv \
	../output/common_raw_equal_transaction.png ../output/common_raw_equal_site_year.png \
	../output/common_event_no_controls.png ../output/common_event_hedonics.png ../output/common_event_fixed_effects.png ../output/common_did_by_ring.png

../output/coefficients.csv ../output/model_summary.csv ../output/site_year_support.csv \
	../output/raw_trends.csv: estimate_rings.R ../input/home_sales_2008_2018.csv \
	../output/ring_assignments.parquet ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< varying

../output/raw_equal_transaction.png ../output/raw_equal_site_year.png ../output/event_no_controls.png \
	../output/event_hedonics.png ../output/event_fixed_effects.png ../output/did_by_ring.png: plot_rings.R \
	../output/raw_trends.csv ../output/coefficients.csv ../output/model_summary.csv ../output/sample_summary.csv \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< varying

../output/common_ring_assignments.parquet ../output/common_support.csv ../output/common_sample_summary.csv \
	../report/common_ring_assignments.txt: build_common_sample.R ../output/ring_assignments.parquet \
	../input/home_sales_2008_2018.csv ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output \
	../report
	$(RSCRIPT) $<

../output/common_coefficients.csv ../output/common_model_summary.csv ../output/common_site_year_support.csv \
	../output/common_raw_trends.csv: estimate_rings.R ../input/home_sales_2008_2018.csv \
	../output/common_ring_assignments.parquet ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< common

../output/common_raw_equal_transaction.png ../output/common_raw_equal_site_year.png \
	../output/common_event_no_controls.png ../output/common_event_hedonics.png \
	../output/common_event_fixed_effects.png ../output/common_did_by_ring.png: plot_rings.R \
	../output/common_raw_trends.csv ../output/common_coefficients.csv ../output/common_model_summary.csv Makefile \
	../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< common

../output/ring_assignments.parquet ../report/ring_assignments.txt ../output/sample_summary.csv: \
	build_ring_sample.R ../input/home_sales_2008_2018.csv ../input/home_school_distances_2006_2025.parquet \
	../input/home_school_exposure_2006_2025.parquet ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | \
	../output ../report
	$(RSCRIPT) $<

../report/saved_tables.txt: report_saved_tables.R ../../../shared/code/report_data.R \
	../output/coefficients.csv \
	../output/model_summary.csv \
	../output/site_year_support.csv \
	../output/raw_trends.csv \
	../output/sample_summary.csv \
	../output/common_coefficients.csv \
	../output/common_model_summary.csv \
	../output/common_site_year_support.csv \
	../output/common_raw_trends.csv \
	../output/common_sample_summary.csv \
	../output/common_support.csv \
	Makefile ../../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_distances_2006_2025.parquet: \
	../../../calculate_home_school_distances/output/home_school_distances_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_2008_2018.csv ../input/home_school_distances_2006_2025.parquet \
	../input/home_school_exposure_2006_2025.parquet

include ../../../shared/code/generic.make
