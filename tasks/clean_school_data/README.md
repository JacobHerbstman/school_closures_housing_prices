# Clean school data

This task cleans the school records supplied by Noah Liu for the February
2013 closure-consideration list. It uses 2011–12 records to fill specified gaps
in the 2012–13 data and substitutes Faraday's location for Garfield Park
because the two schools occupied the same facility. It also attaches 2013–14
records for candidate schools and schools designated to receive displaced
students (welcoming schools). Each welcoming school also carries its 2012–13
location (`welcoming_school_x_coordinate{i}_sy1213` and `_y_`), which
identifies the building it left if it moved into a closed school's building.
Those locations come from the 2012–13 elementary report card, except for the
three special-education schools patched from 2011–12 records; one of these,
Montefiore, is a welcoming school. The cleaner fails if an assigned welcoming
school is missing from either report card.

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
checks of the original list, closure assignments, and locations were in the
retired `home_data_overview` audit (commit `9762b40`).
