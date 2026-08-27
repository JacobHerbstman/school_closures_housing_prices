SHELL := bash
.DEFAULT_GOAL := paper

.PHONY: all paper setup

all: paper

paper: tasks/setup_environment/output/system_requirements.txt
	$(MAKE) -C paper

setup: tasks/setup_environment/output/system_requirements.txt

tasks/setup_environment/output/system_requirements.txt: tasks/setup_environment/code/system_requirements.sh tasks/setup_environment/code/Makefile tasks/generic.make
	$(MAKE) -C tasks/setup_environment/code ../output/system_requirements.txt
