include ../../../shared/code/shell_functions.make

.NOTPARALLEL:

all: ../output/initial_assessment.rds ../output/initial_assessment.pdf ../output/assessment_events.png ../output/assessment_pooled.png

# Preserve the public-data vintage when only estimation, plots or Make change.
../output/assessments_2006_snapshot.tar.gz: download_assessments.R ../input/hedonic_dynamics.rds | ../output ../temp ../report
	$(RSCRIPT) $<

../output/initial_assessment.rds: estimate_assessment.R ../input/hedonic_dynamics.rds ../output/assessments_2006_snapshot.tar.gz ../../../shared/code/report_data.R ../../../setup_environment/output/R_packages.txt Makefile | ../output ../temp ../report
	$(RSCRIPT) $<

../output/initial_assessment.pdf ../output/assessment_events.png ../output/assessment_pooled.png: plot_assessment.R ../output/initial_assessment.rds ../../../setup_environment/output/R_packages.txt Makefile | ../output
	$(RSCRIPT) $<

../input/hedonic_dynamics.rds: ../../home_hedonic_dynamics/output/hedonic_dynamics.rds | ../input
	ln -sf $< $@

link-inputs: ../input/hedonic_dynamics.rds

include ../../../shared/code/generic.make
