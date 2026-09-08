include ../../../shared/code/shell_functions.make

all: ../output/20125il0005000.zip ../output/20125il0043000.zip ../output/20125il0049000.zip ../output/20125il0058000.zip ../output/20125il0078000.zip ../output/20125il0102000.zip ../output/g20125il.csv ../output/sequence_lookup.txt ../output/technical_documentation.pdf ../output/tl_2012_17_tract.zip ../output/tl_2012_17_bg.zip

../output/20125il0005000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0005000.zip' -o $@.tmp
	mv $@.tmp $@

../output/20125il0043000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0043000.zip' -o $@.tmp
	mv $@.tmp $@

../output/20125il0049000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0049000.zip' -o $@.tmp
	mv $@.tmp $@

../output/20125il0058000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0058000.zip' -o $@.tmp
	mv $@.tmp $@

../output/20125il0078000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0078000.zip' -o $@.tmp
	mv $@.tmp $@

../output/20125il0102000.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/20125il0102000.zip' -o $@.tmp
	mv $@.tmp $@

../output/g20125il.csv: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/2008-2012_ACSSF_By_State_By_Sequence_Table_Subset/Illinois/Tracts_Block_Groups_Only/g20125il.csv' -o $@.tmp
	mv $@.tmp $@

../output/sequence_lookup.txt: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/Sequence_Number_and_Table_Number_Lookup.txt' -o $@.tmp
	mv $@.tmp $@

../output/technical_documentation.pdf: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/acs2012_5yr/summaryfile/ACS_2008-2012_SF_Tech_Doc.pdf' -o $@.tmp
	mv $@.tmp $@

../output/tl_2012_17_tract.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/geo/tiger/TIGER2012/TRACT/tl_2012_17_tract.zip' -o $@.tmp
	mv $@.tmp $@

../output/tl_2012_17_bg.zip: Makefile | ../output
	curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 180 'https://www2.census.gov/geo/tiger/TIGER2012/BG/tl_2012_17_bg.zip' -o $@.tmp
	mv $@.tmp $@

include ../../../shared/code/generic.make
