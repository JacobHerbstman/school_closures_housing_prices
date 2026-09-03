# Clean school data

This task reproduces Noah Liu's school-data cleaner using repository-relative
paths and the standard Make task structure. It deliberately preserves the
coauthor's substantive transformations, including the SY2011–12 backfills,
the Garfield Park/Faraday location substitution, and the use of SY2013–14
records for focal and welcoming schools.

The output has one row per school on the February 2013 closure-consideration
list, keyed by `school_id`. This first version is a replication benchmark;
known issues should be corrected in a subsequent, separately reviewable pass.
