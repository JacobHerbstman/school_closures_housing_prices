import csv
import datetime
import os
import subprocess
import tempfile


def download_to_temporary_file(url):
    descriptor, path = tempfile.mkstemp(
        dir="../output",
        prefix=".external_benchmark_download.",
    )
    os.close(descriptor)
    try:
        subprocess.run(
            [
                "curl",
                "--fail",
                "--show-error",
                "--silent",
                "--location",
                "--retry",
                "5",
                "--retry-delay",
                "2",
                "--retry-connrefused",
                "--connect-timeout",
                "60",
                "--max-time",
                "600",
                "--output",
                path,
                url,
            ],
            check=True,
        )
    except Exception:
        os.unlink(path)
        raise
    return path


def read_zillow_region(url, region_id, expected_name, expected_type, series, geography):
    path = download_to_temporary_file(url)
    try:
        with open(path, newline="", encoding="utf-8-sig") as source:
            matches = [
                row for row in csv.DictReader(source) if row["RegionID"] == region_id
            ]
    finally:
        os.unlink(path)
    if len(matches) != 1:
        raise RuntimeError(
            f"Expected one Zillow row for RegionID {region_id}; found {len(matches)}"
        )
    row = matches[0]

    if row["RegionName"] != expected_name or row["RegionType"] != expected_type:
        raise RuntimeError(f"Zillow RegionID {region_id} no longer identifies {expected_name}")

    records = []
    for column, value in row.items():
        if len(column) == 10 and column[4] == "-" and column[7] == "-" and value:
            records.append(
                {
                    "source": "Zillow",
                    "geography": geography,
                    "series": series,
                    "period": column,
                    "value": float(value),
                    "margin_of_error": "",
                }
            )
    if not records:
        raise RuntimeError(f"Zillow series {series} contains no observations")
    return records


def read_acs_chicago_row(url):
    path = download_to_temporary_file(url)
    try:
        with open(path, newline="", encoding="utf-8") as source:
            matches = [
                row
                for row in csv.DictReader(source, delimiter="|")
                if row["GEO_ID"] == "1600000US1714000"
            ]
    finally:
        os.unlink(path)
    if len(matches) != 1:
        raise RuntimeError(f"Expected one Chicago city row in {url}; found {len(matches)}")
    return matches[0]


records = []
records.extend(
    read_zillow_region(
        "https://files.zillowstatic.com/research/public_csvs/zhvi/City_zhvi_uc_sfrcondo_tier_0.33_0.67_sm_sa_month.csv",
        "17426",
        "Chicago",
        "city",
        "home_value_index",
        "Chicago city",
    )
)
records.extend(
    read_zillow_region(
        "https://files.zillowstatic.com/research/public_csvs/median_sale_price/City_median_sale_price_uc_sfrcondo_month.csv",
        "17426",
        "Chicago",
        "city",
        "median_sale_price",
        "Chicago city",
    )
)
records.extend(
    read_zillow_region(
        "https://files.zillowstatic.com/research/public_csvs/sales_count_now/Metro_sales_count_now_uc_sfrcondo_month.csv",
        "394463",
        "Chicago, IL",
        "msa",
        "sales_count_nowcast",
        "Chicago metropolitan area",
    )
)

acs_structure = read_acs_chicago_row(
    "https://www2.census.gov/programs-surveys/acs/summary_file/2024/table-based-SF/data/1YRData/acsdt1y2024-b25032.dat"
)
acs_value = read_acs_chicago_row(
    "https://www2.census.gov/programs-surveys/acs/summary_file/2024/table-based-SF/data/1YRData/acsdt1y2024-b25077.dat"
)

acs_series = {
    "median_owner_occupied_value": (acs_value, "B25077_E001", "B25077_M001"),
    "owner_occupied_units_total": (acs_structure, "B25032_E002", "B25032_M002"),
    "owner_occupied_one_unit_detached": (acs_structure, "B25032_E003", "B25032_M003"),
    "owner_occupied_one_unit_attached": (acs_structure, "B25032_E004", "B25032_M004"),
    "owner_occupied_two_units": (acs_structure, "B25032_E005", "B25032_M005"),
    "owner_occupied_three_to_four_units": (acs_structure, "B25032_E006", "B25032_M006"),
    "owner_occupied_five_to_nine_units": (acs_structure, "B25032_E007", "B25032_M007"),
    "owner_occupied_ten_to_nineteen_units": (acs_structure, "B25032_E008", "B25032_M008"),
    "owner_occupied_twenty_to_forty_nine_units": (acs_structure, "B25032_E009", "B25032_M009"),
    "owner_occupied_fifty_or_more_units": (acs_structure, "B25032_E010", "B25032_M010"),
    "owner_occupied_mobile_home": (acs_structure, "B25032_E011", "B25032_M011"),
    "owner_occupied_boat_rv_other": (acs_structure, "B25032_E012", "B25032_M012"),
}
for series, (row, estimate_column, margin_column) in acs_series.items():
    records.append(
        {
            "source": "ACS 1-year",
            "geography": "Chicago city",
            "series": series,
            "period": "2024",
            "value": float(row[estimate_column]),
            "margin_of_error": float(row[margin_column]),
        }
    )

retrieved_date = datetime.date.today().isoformat()
for record in records:
    record["retrieved_date"] = retrieved_date

output_columns = [
    "source",
    "geography",
    "series",
    "period",
    "value",
    "margin_of_error",
    "retrieved_date",
]
with tempfile.NamedTemporaryFile(
    mode="w",
    newline="",
    encoding="utf-8",
    dir="../output",
    prefix=".external_home_market_benchmarks.",
    suffix=".csv",
    delete=False,
) as temporary_file:
    writer = csv.DictWriter(temporary_file, fieldnames=output_columns)
    writer.writeheader()
    writer.writerows(records)
    temporary_path = temporary_file.name

os.replace(temporary_path, "../output/external_home_market_benchmarks.csv")
print(f"Wrote {len(records)} external benchmark observations.")
