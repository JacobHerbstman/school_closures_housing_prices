# Home distances to baseline amenities

Run `make` from `code/`. The output contains one row per transaction in the
final 2008-2018 price sample, keyed by `row_id`. It joins each transaction to
its sale-year historical parcel centroid and measures straight-line distances
in miles to the Lake Michigan shoreline, the nearest August 2012 park
polygon, and the nearest station in the archived 2012 CTA network. Distance
to a park is zero for a point within its polygon. These are geographic
proximity measures, not walking routes, entrances, or service quality.

Inputs are explicit links to clean sales, the geocoded master, and the
`download_baseline_amenities` audit's geographic sources and metadata. Source
geometries are projected to EPSG:3435 before spatial calculations. The home's
centroid is already in EPSG:3435, whose units are US survey feet; dividing by
5,280 reports miles. Missing centroids remain as missing distances instead of
silently changing the clean price sample.

The August 2012 park layer contains one invalid polygon, Douglas (Stephen),
park 218, with a ring self-intersection. `st_make_valid` repairs that geometry
in memory and all resulting geometries must validate. No park is dropped.
The lake measure uses the boundary of the unique Lake Michigan polygon;
its source edit date is October 14, 2005. Station provenance is documented in
the acquisition task. The same baseline geography is used in every sale year,
including years before 2012; this is not a claim that every 2012 park or
station was already open in 2008.

The normal build writes `output/home_amenity_distances.csv` and a tracked
`report/home_amenity_distances.txt` with schema, completeness, distribution,
key, and fingerprint information.
