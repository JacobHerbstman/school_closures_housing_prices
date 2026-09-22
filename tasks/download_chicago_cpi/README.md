# Download Chicago CPI

This task downloads FRED series `CUURA207SA0`, the CPI-U all-items index for
Chicago-Naperville-Elgin. The cleaner uses its monthly observations to express
home-sale prices in average 2022 dollars. The task requires a complete monthly
series from January 2008 through December 2023, covering both clean-sales
files and the 2022 base year, and does not interpolate CPI values.

Current snapshot: retrieved September 22, 2026, through August 2026; SHA-256
`ef3e21b10c9e245bab67715ee291fdf532c77745e1bef64172e8a147107daf0f`. Relative to
the September 7, 2026 file in `data_raw/county_snapshots_2026-09-07/`, the only
change is the added August 2026 observation; no earlier value was revised.
