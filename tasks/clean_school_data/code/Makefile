include ../../shared/code/shell_functions.make

all: ../output/Elementary_Closure_SY1213_Chicago_Clean.csv ../report/schools.txt

../output/Elementary_Closure_SY1213_Chicago_Clean.csv: clean_school_data.R \
	../input/Elementary_Closure_SY1213_Chicago.csv \
	../input/Elementary_Attendance_SY1213_Chicago.csv \
	../input/Elementary_Report_Card_SY1213_Chicago.csv \
	../input/All_Schools_Report_Card_SY1112_Chicago.csv \
	../input/Elementary_Report_Card_SY1314_Chicago.csv \
	Makefile ../../shared/code/shell_functions.make | ../output
	$(RSCRIPT) $<

../report/schools.txt: report_schools.R ../../shared/code/report_data.R \
	../output/Elementary_Closure_SY1213_Chicago_Clean.csv ../../shared/code/shell_functions.make | ../report
	$(RSCRIPT) $<

../input/Elementary_Closure_SY1213_Chicago.csv: \
	../../raw_school_data/output/Elementary_Closure_SY1213_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/Elementary_Attendance_SY1213_Chicago.csv: \
	../../raw_school_data/output/Elementary_Attendance_SY1213_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/Elementary_Report_Card_SY1213_Chicago.csv: \
	../../raw_school_data/output/Elementary_Report_Card_SY1213_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/All_Schools_Report_Card_SY1112_Chicago.csv: \
	../../raw_school_data/output/All_Schools_Report_Card_SY1112_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

../input/Elementary_Report_Card_SY1314_Chicago.csv: \
	../../raw_school_data/output/Elementary_Report_Card_SY1314_Chicago.csv | ../input
	@test "$$(readlink "$@" 2>/dev/null)" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/Elementary_Closure_SY1213_Chicago.csv \
	../input/Elementary_Attendance_SY1213_Chicago.csv \
	../input/Elementary_Report_Card_SY1213_Chicago.csv \
	../input/All_Schools_Report_Card_SY1112_Chicago.csv \
	../input/Elementary_Report_Card_SY1314_Chicago.csv

include ../../shared/code/generic.make
