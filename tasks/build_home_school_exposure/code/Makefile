all: ../output/home_school_exposure_2006_2025.parquet

../output/home_school_exposure_2006_2025.parquet: build_home_school_exposure.R \
	../input/home_school_distances_2006_2025.parquet \
	Makefile | ../output
	Rscript $<

../input/home_school_distances_2006_2025.parquet: ../../calculate_home_school_distances/output/home_school_distances_2006_2025.parquet | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/home_school_distances_2006_2025.parquet

include ../../generic.make
