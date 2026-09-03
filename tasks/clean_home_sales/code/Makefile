START_YEAR := 2008
END_YEAR := 2018

all: ../output/home_sales_$(START_YEAR)_$(END_YEAR).csv

../output/home_sales_$(START_YEAR)_$(END_YEAR).csv: clean_home_sales.R ../input/corrected_home_sale_characteristics_2006_2025.csv Makefile | ../output
	Rscript $< $(START_YEAR) $(END_YEAR)

../input/corrected_home_sale_characteristics_2006_2025.csv: ../../correct_home_sale_characteristics/output/corrected_home_sale_characteristics_2006_2025.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/corrected_home_sale_characteristics_2006_2025.csv

include ../../generic.make
