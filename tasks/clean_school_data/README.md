# Clean school data

This task cleans the school records supplied by Noah Liu for the February
2013 closure-consideration list. It uses 2011–12 records to fill specified gaps
in the 2012–13 data and substitutes Faraday's location for Garfield Park
because the two schools occupied the same facility. It also attaches 2013–14
records for candidate schools and schools designated to receive displaced
students (welcoming schools).

The output has one row per school on the February 2013 closure-consideration
list, keyed by `school_id`. Schools with identical pre-closure coordinates
share `school_site_id`; `n_candidate_schools_at_site` records how many schools
from the candidate list occupied that site. School performance remains at the
school level rather than being averaged across co-located schools.

The attendance-boundary columns preserve the coauthor's collapsed source
strings for reference. They are not valid spatial geometries and are not used
for point-distance calculations.

The cleaner requires unique school IDs in the 2013–14 report card before
matching programs to receiving schools. `report/schools.txt` describes the saved
129-row output, its key, missing values, and column distributions. Independent
checks of the original list, closure assignments, and locations are in the
`home_data_overview` audit.
