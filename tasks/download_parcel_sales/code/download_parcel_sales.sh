#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf "Usage: %s START_YEAR END_YEAR\n" "$0" >&2
  exit 1
fi

start_year="$1"
end_year="$2"
if ! [[ "$start_year" =~ ^[0-9]{4}$ && "$end_year" =~ ^[0-9]{4}$ ]] || ((start_year > end_year)); then
  printf "START_YEAR and END_YEAR must define a valid year range.\n" >&2
  exit 1
fi

output_file="../output/parcel_sales_${start_year}_${end_year}.csv"
api_csv="https://datacatalog.cookcountyil.gov/resource/wvhk-k5uv.csv"
api_json="https://datacatalog.cookcountyil.gov/resource/wvhk-k5uv.json"
batch_size=500000
where_clause="township_code in('70','71','72','73','74','75','76','77') and year between ${start_year} and ${end_year}"
select_columns="pin,year,township_code,nbhd as neighborhood_code,class,sale_date,is_mydec_date,sale_price,doc_no as sale_document_num,deed_type as sale_deed_type,mydec_deed_type,seller_name as sale_seller_name,is_multisale,num_parcels_sale,buyer_name as sale_buyer_name,sale_type,sale_filter_same_sale_within_365,sale_filter_less_than_10k,sale_filter_deed_type,row_id"

temporary_directory=$(mktemp -d "../output/.parcel_sales.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

read_source_count() {
  curl --fail --show-error --silent --retry 5 --retry-delay 2 --retry-connrefused \
    --connect-timeout 60 --max-time 600 -G "$api_json" \
    --data-urlencode "\$select=count(*)" \
    --data-urlencode "\$where=${where_clause}" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["count"])'
}

download_batch() {
  local destination="$1"
  local offset="$2"

  curl --fail --show-error --silent --retry 5 --retry-delay 2 --retry-connrefused \
    --connect-timeout 60 --max-time 600 -G -o "$destination" "$api_csv" \
    --data-urlencode "\$select=${select_columns}" \
    --data-urlencode "\$where=${where_clause}" \
    --data-urlencode "\$order=row_id" \
    --data-urlencode "\$limit=${batch_size}" \
    --data-urlencode "\$offset=${offset}"
}

inspect_csv() {
  python3 - "$1" <<'PY'
import csv
import json
import sys

csv.field_size_limit(10**9)
with open(sys.argv[1], newline="", encoding="utf-8") as source:
    reader = csv.reader(source, strict=True)
    header = next(reader, None)
    if not header:
        raise SystemExit("CSV response has no header")
    rows = 0
    for line_number, row in enumerate(reader, start=2):
        if len(row) != len(header):
            raise SystemExit(
                f"CSV row {line_number} has {len(row)} fields; expected {len(header)}"
            )
        rows += 1
print(rows)
print(json.dumps(header, separators=(",", ":")))
PY
}

expected_records=$(read_source_count)
if ! [[ "$expected_records" =~ ^[0-9]+$ ]] || ((expected_records == 0)); then
  printf "Could not obtain a positive source row count.\n" >&2
  exit 1
fi

temporary_output="$temporary_directory/parcel_sales.csv"
offset=0
batch_index=0
expected_header=""

printf "Downloading %s Cook County parcel-sale records for %s--%s.\n" \
  "$expected_records" "$start_year" "$end_year"

while ((offset < expected_records)); do
  batch_file="$temporary_directory/batch_${batch_index}.csv"
  download_batch "$batch_file" "$offset"
  inspection=$(inspect_csv "$batch_file")
  records_in_batch=$(printf "%s\n" "$inspection" | sed -n '1p')
  batch_header=$(printf "%s\n" "$inspection" | sed -n '2p')

  if ((records_in_batch == 0)); then
    printf "Empty response at offset %s before the expected row count.\n" "$offset" >&2
    exit 1
  fi

  if ((batch_index == 0)); then
    expected_header="$batch_header"
    cp "$batch_file" "$temporary_output"
  else
    if [[ "$batch_header" != "$expected_header" ]]; then
      printf "CSV header changed at offset %s.\n" "$offset" >&2
      exit 1
    fi
    tail -n +2 "$batch_file" >> "$temporary_output"
  fi

  offset=$((offset + records_in_batch))
  batch_index=$((batch_index + 1))
  printf "  %s of %s records downloaded.\n" "$offset" "$expected_records"
done

final_inspection=$(inspect_csv "$temporary_output")
actual_records=$(printf "%s\n" "$final_inspection" | sed -n '1p')
ending_records=$(read_source_count)

if ((actual_records != expected_records)); then
  printf "Downloaded %s rows; expected %s.\n" "$actual_records" "$expected_records" >&2
  exit 1
fi
if ((ending_records != expected_records)); then
  printf "Source count changed during download: %s to %s.\n" \
    "$expected_records" "$ending_records" >&2
  exit 1
fi

mv "$temporary_output" "$output_file"
printf "Wrote %s source records to %s.\n" "$actual_records" "$output_file"
