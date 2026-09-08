include ../../shared/code/shell_functions.make

START_YEAR := 2008
END_YEAR := 2018

all: ../output/home_sales_$(START_YEAR)_$(END_YEAR).csv ../report/home_sales_$(START_YEAR)_$(END_YEAR).txt

../output/home_sales_$(START_YEAR)_$(END_YEAR).csv: clean_home_sales.R \
	../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/chicago_cpi_all_items.csv \
	Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../report/home_sales_$(START_YEAR)_$(END_YEAR).txt: report_sales.R ../../shared/code/report_data.R \
	../output/home_sales_$(START_YEAR)_$(END_YEAR).csv Makefile ../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $< $(START_YEAR) $(END_YEAR)

../input/corrected_home_sale_characteristics_2006_2025.csv: \
	../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/chicago_cpi_all_items.csv: ../../download_chicago_cpi/output/chicago_cpi_all_items.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/chicago_cpi_all_items.csv

include ../../shared/code/generic.make
