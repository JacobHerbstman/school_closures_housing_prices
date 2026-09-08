include tasks/shared/code/shell_functions.make

.DEFAULT_GOAL := paper

.PHONY: all paper setup

all: paper

paper: tasks/setup_environment/output/system_requirements.txt
	$(MAKE) -C paper

setup: tasks/setup_environment/output/system_requirements.txt tasks/setup_environment/output/R_packages.txt

tasks/setup_environment/output/system_requirements.txt: tasks/setup_environment/code/system_requirements.sh tasks/setup_environment/code/Makefile tasks/shared/code/generic.make tasks/shared/code/shell_functions.make
	$(MAKE) -C tasks/setup_environment/code ../output/system_requirements.txt

tasks/setup_environment/output/R_packages.txt: tasks/setup_environment/code/packages.R tasks/setup_environment/code/Makefile tasks/shared/code/generic.make tasks/shared/code/shell_functions.make
	$(MAKE) -C tasks/setup_environment/code ../output/R_packages.txt
