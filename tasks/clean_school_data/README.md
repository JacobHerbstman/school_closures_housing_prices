# Clean school data

This task reproduces Noah Liu's school-data cleaner using repository-relative
paths and the standard Make task structure. It deliberately preserves the
coauthor's substantive transformations, including the SY2011–12 backfills,
the Garfield Park/Faraday location substitution, and the use of SY2013–14
records for focal and welcoming schools.

The output has one row per school on the February 2013 closure-consideration
list, keyed by `school_id`. Schools with identical pre-closure coordinates
share `school_site_id`; `n_candidate_schools_at_site` records how many schools
from the candidate list occupied that site. School performance remains at the
school level rather than being averaged across co-located schools.

The attendance-boundary columns preserve the coauthor's collapsed source
strings for reference. They are not valid spatial geometries and are not used
for point-distance calculations.
