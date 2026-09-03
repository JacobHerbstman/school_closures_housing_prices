# Download historical home-improvement exemptions

Run `make` from `code/`. This task owns the raw downloads in
`data_raw/home_improvement_exemptions/` and exposes them as output symlinks.
Existing raw files are never overwritten. The source snapshot was retrieved
on 2026-09-02; exact URLs are in the Makefile.

- `hie_data.parquet`: Cook County Assessor residential model input, run
  `2026-07-30-ecstatic-carly`, S3 version
  `A.Vx1duMBXlIhnjOQDatleZwljvsFun6`. Contains 134,096 legacy exemption rows
  beginning in 2000–2020, with published inclusive expiration years.
- `ccao.zip`: the Assessor's public R package at commit
  `419b67731a1aeb1fa1d2b47b0ed6c3391f5c653a`. Production reads its field map
  and categorical dictionaries, not executable valuation code. The archive
  includes the package's AGPL-3 license.
- `legacy_improvement_metadata.json`: public dataset `bcnq-qi2z` metadata,
  including the legacy residence-code definition. This endpoint is mutable;
  the local snapshot is preserved.

The correction task verifies SHA-256 fingerprints for both pinned binary
sources. The original HIE audit uses these same raw files; production never
depends on audit outputs.
