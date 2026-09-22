include ../../shared/code/shell_functions.make

# The 2008-2018 sample is the regression sample; 2008-2023 extends the same
# within-year rules for the longer descriptive packet.
all: ../output/home_sales_2008_2018.csv ../output/home_sales_2008_2023.csv

../output/home_sales_2008_%.csv: clean_home_sales.R ../../shared/code/report_data.R \
	../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/parcel_sales_2006_2025.csv ../input/chicago_cpi_all_items.csv \
	Makefile ../../shared/code/shell_functions.make | ../output ../report
	$(RSCRIPT) $< 2008 $*

../input/corrected_home_sale_characteristics_2006_2025.csv: \
	../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/parcel_sales_2006_2025.csv: ../../download_parcel_sales/output/parcel_sales_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/chicago_cpi_all_items.csv: ../../download_chicago_cpi/output/chicago_cpi_all_items.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv \
	../input/parcel_sales_2006_2025.csv ../input/chicago_cpi_all_items.csv

include ../../shared/code/generic.make
