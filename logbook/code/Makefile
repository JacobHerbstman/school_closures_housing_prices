include ../../tasks/shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/logbook.pdf

../output/logbook.pdf: logbook.tex ../entries/2026-09-07-working-cleaning-version.tex ../entries/2026-09-07-county-sale-flags.tex ../input/sale_flags_table.tex \
	../entries/2026-09-07-trends-without-complete-characteristics.tex ../input/overview_complete_prices.png \
	../entries/2026-09-07-data-review-and-raw-trends.tex ../input/overview_price_trends.png \
	../input/overview_data_review.rds ../entries/2026-09-07-initial-prices-in-log-models.tex \
	../input/initial_price_log_events.png ../entries/2026-09-07-initial-prices-and-year-effects.tex \
	../input/initial_price_events.png ../input/initial_price_coefficients.csv ../input/initial_price_sites.csv \
	../input/initial_price_models.csv ../entries/2026-09-07-what-is-in-the-upper-tail.tex \
	../output/upper_tail_table.tex ../input/price_band_periods.csv \
	../entries/2026-09-07-price-distribution-and-site-influence.tex ../input/annual_price_distribution.png \
	../input/expensive_sales_contribution.png ../input/property_composition.png ../input/site_omission_did.png \
	../input/site_omission_events.png ../entries/2026-09-07-transaction-weights-and-price-scale.tex \
	../entries/2026-09-07-return-to-30-49.tex ../entries/2026-09-04-common-distance-rings.tex \
	../output/common_ring_table.tex ../input/ring_common_raw_equal_site_year.png \
	../input/ring_common_event_hedonics.png ../input/ring_common_event_fixed_effects.png \
	../input/ring_common_did_by_ring.png ../entries/2026-09-04-distance-rings.tex ../output/ring_table.tex \
	../input/ring_raw_equal_site_year.png ../input/ring_event_hedonics.png ../input/ring_event_fixed_effects.png \
	../input/ring_did_by_ring.png ../entries/2026-09-04-site-weighted-prices.tex ../output/site_weight_table.tex \
	../input/raw_prices_annual.png ../input/event_studies_weights_annual.png ../input/raw_prices_semiannual.png \
	../input/event_studies_weights_semiannual.png ../input/event_studies_weights_amenities.png \
	../entries/2026-09-04-baseline-demographics.tex ../output/demographic_table.tex \
	../input/demographic_balance.png ../entries/2026-09-04-comparison-design.tex ../output/comparison_weights.txt \
	../entries/2026-09-04-housing-hedonics.tex ../entries/2026-09-04-amenity-controls.tex ../output/twfe_table.tex \
	../output/amenity_table.tex ../input/event_studies.png ../input/event_studies_semiannual.png \
	../input/event_studies_amenities.png Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(LATEX) -interaction=nonstopmode -halt-on-error -output-directory=../output $<

../output/twfe_table.tex ../output/amenity_table.tex: write_twfe_table.R ../input/coefficients.csv \
	../input/model_summary.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/comparison_weights.txt: review_comparison.R ../input/site_year_support.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/demographic_table.tex: write_demographic_table.R ../input/demographic_balance.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../output/site_weight_table.tex: write_site_weight_table.R ../input/coefficients.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<


../output/ring_table.tex: write_ring_table.R ../input/ring_coefficients.csv ../input/ring_sample_summary.csv \
	Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< varying


../output/common_ring_table.tex: write_ring_table.R ../input/ring_common_coefficients.csv \
	../input/ring_common_sample_summary.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< common

../output/upper_tail_table.tex: write_upper_tail_table.R ../input/upper_tail_sites.csv Makefile ../../tasks/shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../input/coefficients.csv: ../../tasks/audits/home_prices_twfe/output/coefficients.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/model_summary.csv: ../../tasks/audits/home_prices_twfe/output/model_summary.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies.png: ../../tasks/audits/home_prices_twfe/output/event_studies.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies_semiannual.png: ../../tasks/audits/home_prices_twfe/output/event_studies_semiannual.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies_amenities.png: ../../tasks/audits/home_prices_twfe/output/event_studies_amenities.png | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/site_year_support.csv: ../../tasks/audits/home_prices_twfe/output/site_year_support.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/demographic_balance.csv: ../../tasks/audits/home_baseline_demographics/output/demographic_balance.csv \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/demographic_balance.png: ../../tasks/audits/home_baseline_demographics/output/demographic_balance.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/raw_prices_annual.png: ../../tasks/audits/home_prices_twfe/output/raw_prices_annual.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies_weights_annual.png: \
	../../tasks/audits/home_prices_twfe/output/event_studies_weights_annual.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/raw_prices_semiannual.png: ../../tasks/audits/home_prices_twfe/output/raw_prices_semiannual.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies_weights_semiannual.png: \
	../../tasks/audits/home_prices_twfe/output/event_studies_weights_semiannual.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/event_studies_weights_amenities.png: \
	../../tasks/audits/home_prices_twfe/output/event_studies_weights_amenities.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_raw_equal_site_year.png: ../../tasks/audits/home_price_rings/output/raw_equal_site_year.png | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_event_hedonics.png: ../../tasks/audits/home_price_rings/output/event_hedonics.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_event_fixed_effects.png: ../../tasks/audits/home_price_rings/output/event_fixed_effects.png | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_did_by_ring.png: ../../tasks/audits/home_price_rings/output/did_by_ring.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_coefficients.csv: ../../tasks/audits/home_price_rings/output/coefficients.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_sample_summary.csv: ../../tasks/audits/home_price_rings/output/sample_summary.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_raw_equal_site_year.png: \
	../../tasks/audits/home_price_rings/output/common_raw_equal_site_year.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_event_hedonics.png: ../../tasks/audits/home_price_rings/output/common_event_hedonics.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_event_fixed_effects.png: \
	../../tasks/audits/home_price_rings/output/common_event_fixed_effects.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_did_by_ring.png: ../../tasks/audits/home_price_rings/output/common_did_by_ring.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_coefficients.csv: ../../tasks/audits/home_price_rings/output/common_coefficients.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ring_common_sample_summary.csv: ../../tasks/audits/home_price_rings/output/common_sample_summary.csv \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/annual_price_distribution.png: \
	../../tasks/audits/home_price_distribution/output/annual_price_distribution.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/expensive_sales_contribution.png: \
	../../tasks/audits/home_price_distribution/output/expensive_sales_contribution.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/property_composition.png: ../../tasks/audits/home_price_distribution/output/property_composition.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/site_omission_did.png: ../../tasks/audits/home_price_distribution/output/site_omission_did.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/site_omission_events.png: ../../tasks/audits/home_price_distribution/output/site_omission_events.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/upper_tail_sites.csv: ../../tasks/audits/home_price_distribution/output/upper_tail_sites.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/price_band_periods.csv: ../../tasks/audits/home_price_distribution/output/price_band_periods.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/initial_price_events.png: ../../tasks/audits/home_price_distribution/output/initial_price_events.png \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/initial_price_coefficients.csv: \
	../../tasks/audits/home_price_distribution/output/initial_price_coefficients.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/initial_price_sites.csv: ../../tasks/audits/home_price_distribution/output/initial_price_sites.csv | \
	../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/initial_price_models.csv: ../../tasks/audits/home_price_distribution/output/initial_price_models.csv \
	| ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/initial_price_log_events.png: \
	../../tasks/audits/home_price_distribution/output/initial_price_log_events.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_price_trends.png: ../../tasks/audits/home_data_overview/output/price_trends.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_data_review.rds: ../../tasks/audits/home_data_overview/output/data_review.rds | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/overview_complete_prices.png: \
	../../tasks/audits/home_data_overview/output/complete_characteristics_price_trends.png | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/sale_flags_table.tex: ../../tasks/audits/home_sale_quality_flags/output/sale_flags_table.tex | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/sale_flags_table.tex ../input/overview_complete_prices.png \
	../input/overview_price_trends.png ../input/overview_data_review.rds ../input/initial_price_log_events.png \
	../input/initial_price_events.png ../input/initial_price_coefficients.csv ../input/initial_price_sites.csv \
	../input/initial_price_models.csv ../input/upper_tail_sites.csv ../input/price_band_periods.csv \
	../input/annual_price_distribution.png ../input/expensive_sales_contribution.png \
	../input/property_composition.png ../input/site_omission_did.png ../input/site_omission_events.png \
	../input/ring_common_raw_equal_site_year.png ../input/ring_common_event_hedonics.png \
	../input/ring_common_event_fixed_effects.png ../input/ring_common_did_by_ring.png \
	../input/ring_common_coefficients.csv ../input/ring_common_sample_summary.csv \
	../input/ring_raw_equal_site_year.png ../input/ring_event_hedonics.png ../input/ring_event_fixed_effects.png \
	../input/ring_did_by_ring.png ../input/ring_coefficients.csv ../input/ring_sample_summary.csv \
	../input/raw_prices_annual.png ../input/event_studies_weights_annual.png ../input/raw_prices_semiannual.png \
	../input/event_studies_weights_semiannual.png ../input/event_studies_weights_amenities.png \
	../input/demographic_balance.csv ../input/demographic_balance.png ../input/site_year_support.csv \
	../input/coefficients.csv ../input/model_summary.csv ../input/event_studies.png \
	../input/event_studies_semiannual.png ../input/event_studies_amenities.png

include ../../tasks/shared/code/generic.make
