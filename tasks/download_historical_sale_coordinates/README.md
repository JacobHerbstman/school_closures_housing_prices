# Download historical sale coordinates

This task requests the historical Cook County parcel-universe record for each
unique PIN and sale year in the broad 2006--2025 master transaction universe.
The download is independent of analytical selection so future sample changes
do not require reacquiring coordinates or recalculating all-school distances.

Source: Cook County Assessor, [Parcel
Universe](https://datacatalog.cookcountyil.gov/resource/nj4t-kc8j).

The output is one row per sale PIN-year and records whether the historical
source supplies a complete coordinate set. The task fails if the source omits
a requested key or returns duplicate keys. It does not substitute current
parcel coordinates for missing historical coordinates.

Longitude/latitude are EPSG:4326; projected centroids are EPSG:3435 in US survey
feet. The finalization audit independently checks the transformation. Run
`make` from `code/`.
