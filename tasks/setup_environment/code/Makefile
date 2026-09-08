include ../../shared/code/shell_functions.make

all: ../output/system_requirements.txt ../output/R_packages.txt

../output/system_requirements.txt: system_requirements.sh Makefile | ../output
	bash $<

../output/R_packages.txt: packages.R Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<


include ../../shared/code/generic.make
