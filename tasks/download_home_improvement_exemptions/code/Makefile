include ../../shared/code/shell_functions.make

all: ../output/hie_data.parquet ../output/ccao.zip ../output/legacy_improvement_metadata.json

../output/hie_data.parquet: ../../../data_raw/home_improvement_exemptions/hie_data.parquet | ../output
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../output/ccao.zip: ../../../data_raw/home_improvement_exemptions/ccao.zip | ../output
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../output/legacy_improvement_metadata.json: ../../../data_raw/home_improvement_exemptions/legacy_improvement_metadata.json | ../output
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../../../data_raw/home_improvement_exemptions/hie_data.parquet: | ../../../data_raw/home_improvement_exemptions
	curl --fail --location --show-error --max-time 120 'https://ccao-data-public-us-east-1.s3.amazonaws.com/models/inputs/res/2026/run_id=2026-07-30-ecstatic-carly/hie_data.parquet?versionId=A.Vx1duMBXlIhnjOQDatleZwljvsFun6' -o $@.tmp
	mv $@.tmp $@

../../../data_raw/home_improvement_exemptions/ccao.zip: | ../../../data_raw/home_improvement_exemptions
	curl --fail --location --show-error --max-time 120 'https://codeload.github.com/ccao-data/ccao/zip/419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a' -o $@.tmp
	mv $@.tmp $@

../../../data_raw/home_improvement_exemptions/legacy_improvement_metadata.json: | ../../../data_raw/home_improvement_exemptions
	curl --fail --location --show-error --max-time 120 'https://datacatalog.cookcountyil.gov/api/views/bcnq-qi2z' -o $@.tmp
	mv $@.tmp $@

../../../data_raw/home_improvement_exemptions:
	mkdir -p $@

include ../../shared/code/generic.make
