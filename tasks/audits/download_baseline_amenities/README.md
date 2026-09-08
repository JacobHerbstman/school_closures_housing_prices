# Baseline Chicago amenity geography

Run `make` from `code/`. This audit acquisition task downloads the geographic
sources for the amenity controls. The station and park layers describe 2012;
the selected Lake Michigan feature carries an October 14, 2005 edit date.

- Parks: Chicago Data Portal dataset `5msb-wbxn`, archived
  `Parks_Aug2012.zip`, 583 polygons. The portal now calls this deprecated and
  its generic time-period field says through November 2016; the archive and
  internal layer explicitly identify August 2012. We use that archive rather
  than the replacement 2016 park layer.
- CTA stations: Esri-hosted preservation of the City of Chicago station layer,
  `Imagery_Explorer_Reference_Layers/FeatureServer/2`. Its metadata says the
  source was downloaded in March 2013 and dates to 2012. It has 145 stations,
  including Morgan and Oakton-Skokie, and excludes later stations such as
  Cermak-McCormick Place. This is an archived copy, not today's official
  station download, which now describes September 2023. The archive item is
  `e1775afc8a3a4543a946bc8fb2d6af1a`, owned by
  `knightlinger@esri.com_prof_services`. The geographic vintage relies on that
  preservation metadata; it is not an independently recovered 2012 GTFS feed.
- Water: Chicago Data Portal `knfe-65pw`; the consumer selects the unique
  `LAKE MICHIGAN` polygon and checks its `edit_date1` value `10-14-05`.

The Makefile records the download URLs. Park and station metadata are saved
alongside the geometries. Existing downloads persist until their prerequisites
change or they are deliberately removed for refresh. The downstream distance
report records hashes of the three downloaded geographic files, so a changed
source is visible. Raw downloads are never edited in place.

These are fixed pre-closure amenity locations, not historical service or
park-quality panels. CTA proximity does not model the 2013 Red Line South
shutdown and reconstruction separately. Metra and bus access are not included.
