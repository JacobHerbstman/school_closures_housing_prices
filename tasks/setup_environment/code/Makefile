all: ../output/system_requirements.txt ../output/R_packages.txt

../output/system_requirements.txt: system_requirements.sh Makefile | ../output
	bash $<

../output/R_packages.txt: packages.R Makefile | ../output
	Rscript $<

link-inputs:

include ../../generic.make
