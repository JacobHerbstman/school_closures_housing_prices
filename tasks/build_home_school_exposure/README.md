# Build home-school exposure

This task reduces the complete home-school distance matrix to one row per home
sale, keyed by `row_id`. It records the nearest treated, control, other
candidate, and welcoming locations and their distances in feet.

The task also counts how many locations of each type fall within 0.25 miles
(1,320 feet). `focal_exposure_025` distinguishes treated-only, control-only,
treated-control overlap, outside-ring, and missing-coordinate sales. A sale
near multiple sites of the same type remains in that treatment category; the
counts preserve the multiple exposure without duplicating the sale.
Nearest-location ties are resolved deterministically in favor of the lower
school or site identifier.

No observations are dropped. Proximity to welcoming schools and other
candidate sites is retained but does not change `focal_exposure_025`. Final
sample restrictions belong in a downstream analysis task.
