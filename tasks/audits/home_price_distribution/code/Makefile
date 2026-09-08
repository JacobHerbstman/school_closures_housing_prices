include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/initial_price_sites.csv \
	../output/initial_price_coefficients.csv \
	../output/initial_price_models.csv \
	../output/initial_price_events.png \
	../output/initial_price_log_events.png \
	../report/initial_price_sites.txt \
	../report/initial_price_coefficients.txt \
	../report/initial_price_models.txt \
	../output/price_band_periods.csv \
	../output/upper_tail_sites.csv \
	../report/price_band_periods.txt \
	../report/upper_tail_sites.txt \
	../output/analysis_sample.csv \
	../output/annual_prices.csv \
	../output/tail_contributions.csv \
	../output/expensive_sales.csv \
	../output/property_composition.csv \
	../output/site_omission_coefficients.csv \
	../output/site_omission_models.csv \
	../output/annual_price_distribution.png \
	../output/expensive_sales_contribution.png \
	../output/property_composition.png \
	../output/site_omission_did.png \
	../output/site_omission_events.png \
	../report/analysis_sample.txt \
	../report/annual_prices.txt \
	../report/tail_contributions.txt \
	../report/expensive_sales.txt \
	../report/property_composition.txt \
	../report/site_omission_coefficients.txt \
	../report/site_omission_models.txt

../output/annual_prices.csv ../output/tail_contributions.csv ../output/expensive_sales.csv \
	../output/property_composition.csv: describe_prices.R ../output/analysis_sample.csv Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/annual_price_distribution.png ../output/expensive_sales_contribution.png \
	../output/property_composition.png ../output/site_omission_did.png ../output/site_omission_events.png: \
	plot_diagnostics.R ../output/annual_prices.csv ../output/tail_contributions.csv \
	../output/property_composition.csv ../output/site_omission_coefficients.csv ../output/site_omission_models.csv \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/analysis_sample.csv: build_sample.R ../input/home_sales_2008_2018.csv \
	../input/home_school_exposure_2006_2025.parquet ../input/schools.csv ../input/baseline_site_year_support.csv \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/site_omission_coefficients.csv ../output/site_omission_models.csv: estimate_influence.R \
	../output/analysis_sample.csv ../input/baseline_coefficients.csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/price_band_periods.csv ../output/upper_tail_sites.csv: trace_upper_tail.R \
	../output/analysis_sample.csv Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/initial_price_sites.csv ../output/initial_price_coefficients.csv ../output/initial_price_models.csv: \
	estimate_initial_prices.R ../output/analysis_sample.csv ../input/baseline_coefficients.csv \
	../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/initial_price_events.png: plot_initial_prices.R ../output/initial_price_coefficients.csv Makefile ../../../shared/code/shell_functions.make | \
	../output
	$(RSCRIPT) $< dollars

../output/initial_price_log_events.png: plot_initial_prices.R ../output/initial_price_coefficients.csv \
	Makefile ../../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< log

../report/%.txt: report_data.R ../../../shared/code/report_data.R ../output/%.csv Makefile ../../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $< $*

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/home_school_exposure_2006_2025.parquet: \
	../../../build_home_school_exposure/output/home_school_exposure_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/schools.csv: ../../../clean_school_data/output/Elementary_Closure_SY1213_Chicago_Clean.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/baseline_coefficients.csv: ../../home_prices_twfe/output/coefficients.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/baseline_site_year_support.csv: ../../home_prices_twfe/output/site_year_support.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_2008_2018.csv ../input/home_school_exposure_2006_2025.parquet \
	../input/schools.csv ../input/baseline_coefficients.csv ../input/baseline_site_year_support.csv

include ../../../shared/code/generic.make
