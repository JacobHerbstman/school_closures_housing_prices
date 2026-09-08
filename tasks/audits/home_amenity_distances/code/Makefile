include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/home_amenity_distances.csv ../report/home_amenity_distances.txt

../output/home_amenity_distances.csv ../report/home_amenity_distances.txt: build_amenity_distances.R \
	../input/home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/parks_aug2012.zip ../input/parks_metadata.json ../input/cta_2012.geojson ../input/cta_metadata.json \
	../input/chicago_hydro.geojson ../../../setup_environment/output/R_packages.txt Makefile ../../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $<

../input/home_sales_2008_2018.csv: ../../../clean_home_sales/output/home_sales_2008_2018.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/geocoded_master_home_transactions_2006_2025.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/parks_aug2012.zip: ../../download_baseline_amenities/output/parks_aug2012.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/parks_metadata.json: ../../download_baseline_amenities/output/parks_metadata.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/cta_2012.geojson: ../../download_baseline_amenities/output/cta_2012.geojson | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/cta_metadata.json: ../../download_baseline_amenities/output/cta_metadata.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/chicago_hydro.geojson: ../../download_baseline_amenities/output/chicago_hydro.geojson | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_2008_2018.csv ../input/geocoded_master_home_transactions_2006_2025.csv \
	../input/parks_aug2012.zip ../input/parks_metadata.json ../input/cta_2012.geojson ../input/cta_metadata.json \
	../input/chicago_hydro.geojson

include ../../../shared/code/generic.make
