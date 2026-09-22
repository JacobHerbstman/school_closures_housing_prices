include ../../../shared/code/shell_functions.make

all: ../output/sale_tract_change.csv

../output/sale_tract_change.csv: build_tract_change.R ../output/census_tract_counts.csv ../output/il17trf.txt \
	../output/tl_2010_17031_tract10.zip ../input/geocoded_master_home_transactions_2006_2025.csv \
	../../../shared/code/report_data.R Makefile | ../output ../report ../temp
	$(RSCRIPT) $<

# Fixed Census releases: 2000 SF3 and 2008-2012 ACS tract counts (API key read
# from the ignored project .Renviron), the 2000-2010 tract relationship file,
# and 2010 Cook County tract boundaries.
../output/census_tract_counts.csv: download_census_tracts.R | ../output ../temp
	$(RSCRIPT) $<

../output/il17trf.txt: | ../output
	curl --fail --location --silent --show-error --retry 2 --max-time 120 'https://www2.census.gov/geo/docs/maps-data/data/rel/trf_txt/il17trf.txt' -o $@.tmp
	mv $@.tmp $@

../output/tl_2010_17031_tract10.zip: | ../output
	curl --fail --location --silent --show-error --retry 2 --max-time 120 'https://www2.census.gov/geo/tiger/TIGER2010/TRACT/2010/tl_2010_17031_tract10.zip' -o $@.tmp
	mv $@.tmp $@

../input/geocoded_master_home_transactions_2006_2025.csv: \
	../../../build_geocoded_home_sales/output/geocoded_master_home_transactions_2006_2025.csv | ../input
	ln -sf $< $@

link-inputs: ../input/geocoded_master_home_transactions_2006_2025.csv

include ../../../shared/code/generic.make
