include ../../shared/code/shell_functions.make

all: ../output/corrected_home_sale_characteristics_2006_2025.csv \
	../report/corrected_home_sale_characteristics_2006_2025.txt

../output/corrected_home_sale_characteristics_2006_2025.csv: correct_home_sale_characteristics.R \
	../input/home_sales_with_characteristics_2006_2025.csv ../input/hie_data.parquet ../input/ccao.zip \
	../input/legacy_improvement_metadata.json Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/corrected_home_sale_characteristics_2006_2025.txt: report_sales.R ../../shared/code/report_data.R \
	../output/corrected_home_sale_characteristics_2006_2025.csv Makefile ../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/home_sales_with_characteristics_2006_2025.csv: \
	../../build_home_sale_characteristics/output/home_sales_with_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/hie_data.parquet: ../../download_home_improvement_exemptions/output/hie_data.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/ccao.zip: ../../download_home_improvement_exemptions/output/ccao.zip | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/legacy_improvement_metadata.json: \
	../../download_home_improvement_exemptions/output/legacy_improvement_metadata.json | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_sales_with_characteristics_2006_2025.csv ../input/hie_data.parquet \
	../input/ccao.zip ../input/legacy_improvement_metadata.json

include ../../shared/code/generic.make
