# Calculate home-school distances

This task calculates straight-line distances from every transaction in the
2006--2025 geocoded home-sales master to every school location needed for the
initial closure analysis. Distances are measured in feet using Illinois
StatePlane East coordinates (EPSG:3435).

Candidate schools sharing pre-closure coordinates are represented by one
`candidate_site` location. This leaves 127 candidate sites: 29 treated, 49
controls, and 49 neither. The 48 distinct welcoming schools are represented
separately at their SY2013--14 locations because a school can have different
pre-closure and welcoming-school locations.

The Parquet output has one row per transaction and role-specific school
location. Its key is `row_id`, `school_location_role`, and
`school_location_id`. The location identifier is `school_site_id` for a
candidate site and `school_id` for a welcoming school. Treatment and control
flags apply only to candidate sites. Six transactions without historical
coordinates are retained with missing distance rather than being silently
dropped.

The task does not select a nearest school, impose distance rings, or resolve
overlapping exposure. Those analytical choices belong in a downstream sample
construction task.
