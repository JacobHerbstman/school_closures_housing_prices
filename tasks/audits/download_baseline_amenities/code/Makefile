include ../../../shared/code/shell_functions.make

all: ../output/parks_aug2012.zip ../output/parks_metadata.json ../output/cta_2012.geojson ../output/cta_metadata.json ../output/chicago_hydro.geojson

../output/parks_aug2012.zip: Makefile | ../output
	curl -L --fail --silent --show-error 'https://data.cityofchicago.org/download/5msb-wbxn/application%2Fzip' -o $@

../output/parks_metadata.json: Makefile | ../output
	curl -L --fail --silent --show-error 'https://data.cityofchicago.org/api/views/5msb-wbxn.json' -o $@

../output/cta_2012.geojson: Makefile | ../output
	curl -L --fail --silent --show-error 'https://services1.arcgis.com/wQnFk5ouCfPzTlPw/ArcGIS/rest/services/Imagery_Explorer_Reference_Layers/FeatureServer/2/query?where=1%3D1&outFields=*&outSR=4326&f=geojson' -o $@

../output/cta_metadata.json: Makefile | ../output
	curl -L --fail --silent --show-error 'https://services1.arcgis.com/wQnFk5ouCfPzTlPw/ArcGIS/rest/services/Imagery_Explorer_Reference_Layers/FeatureServer/2?f=pjson' -o $@

../output/chicago_hydro.geojson: Makefile | ../output
	curl -L --fail --silent --show-error 'https://data.cityofchicago.org/resource/knfe-65pw.geojson?$$limit=5000' -o $@

include ../../../shared/code/generic.make
