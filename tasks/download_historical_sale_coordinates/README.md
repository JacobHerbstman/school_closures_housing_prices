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
feet. A retired finalization audit (commit `9762b40`) independently checked the transformation. The
extract is written to `../temp` and moved into `output/` only after every
request succeeds and the key checks pass. Run `make` from `code/`.

Current snapshot: retrieved September 22, 2026; 399,882 PIN-years, 399,876 with
complete coordinates; SHA-256
`71e7c3841cf9396fd24a75fb51749c984df2620f329e071344548aa4aec1ae77`,
byte-identical to the September 7, 2026 extract preserved in
`data_raw/county_snapshots_2026-09-07/`.
