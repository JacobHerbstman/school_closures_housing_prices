include ../../shared/code/shell_functions.make

all: ../output/All_Schools_Report_Card_SY1112_Chicago.csv \
	../output/Elementary_Attendance_SY1213_Chicago.csv \
	../output/Elementary_Closure_SY1213_Chicago.csv \
	../output/Elementary_Report_Card_SY1213_Chicago.csv \
	../output/Elementary_Report_Card_SY1314_Chicago.csv

../output/consortium_school_closings_2015.pdf: Makefile | ../output
	curl --fail --location --show-error --max-time 120 'https://consortium.uchicago.edu/sites/default/files/2018-10/School%20Closings%20Report.pdf' -o $@.tmp
	mv $@.tmp $@

../output/fermi_south_shore_2013.pdf: Makefile | ../output
	curl --fail --location --show-error --max-time 120 'https://schoolinfo.cps.edu/SchoolActions/Download.aspx?fid=1706' -o $@.tmp
	mv $@.tmp $@

../output/garfield_faraday_2013.pdf: Makefile | ../output
	curl --fail --location --show-error --max-time 120 'https://schoolinfo.cps.edu/SchoolActions/Download.aspx?fid=1708' -o $@.tmp
	mv $@.tmp $@

../output/cps_february_2013_list.pdf: Makefile | ../output
	curl --fail --location --show-error --max-time 120 'https://dig.abclocal.go.com/wls/documents/cps-list.pdf' -o $@.tmp
	mv $@.tmp $@

include ../../shared/code/generic.make
