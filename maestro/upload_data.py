"""Reads all Excels and stations.csv and uploads the data to maestro schema.

Creates two tables: noise_measurements, stations
"""

import os
import glob
import math
import pandas as pd
from sqlalchemy import create_engine, text

from config import DB_URL as DB_CONN

# ---------- CONFIG ----------
EXCEL_DIR = "data"   # folder with Q1_2022 ... Q2_2025 .xlsx files
STATIONS_CSV = "./data/stations.csv"  # columns: campaign,name,lon,lat
# ----------------------------

engine = create_engine(DB_CONN)

DDL_SQL = """
CREATE SCHEMA IF NOT EXISTS maestro;

CREATE TABLE IF NOT EXISTS maestro.stations (
    campaign   text PRIMARY KEY,
    name       text NOT NULL,
    geom       geometry(Point, 2154)  -- LAMBERT-93 / EPSG:2154,
    range_m    smallint
);

CREATE TABLE IF NOT EXISTS maestro.noise_measurements (
    id              bigserial PRIMARY KEY,
    campaign        text NOT NULL REFERENCES maestro.stations(campaign),
    start_local     timestamp NOT NULL,
    end_local       timestamp NOT NULL,
    maxts_local     timestamp,
    type_avion      text,
    flight_number   smallint,
    duration_s      numeric,
    direction       text,
    alt             smallint,
    alt_m           numeric,
    laeq            numeric,
    sel             numeric,
    lamax1s         numeric,
    precipitation   text,
    windspeed       numeric,
    humidity        numeric
);

-- Helpful indexes (idempotent via IF NOT EXISTS in PG13+; otherwise try/except in Python)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname='maestro' AND indexname='noise_measurements_campaign_idx'
    ) THEN
        CREATE INDEX noise_measurements_campaign_idx ON maestro.noise_measurements (campaign);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname='maestro' AND indexname='noise_measurements_start_local_idx'
    ) THEN
        CREATE INDEX noise_measurements_start_local_idx ON maestro.noise_measurements (start_local);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname='maestro' AND indexname='noise_measurements_flight_number_idx'
    ) THEN
        CREATE INDEX noise_measurements_flight_number_idx ON maestro.noise_measurements (flight_number);
    END IF;
END$$;
"""

def run_ddl():
    with engine.begin() as conn:
        conn.execute(text(DDL_SQL))

def safe_float(x):
    try:
        if x is None or (isinstance(x, float) and math.isnan(x)):
            return None
        return float(x)
    except Exception:
        return None

def load_stations_csv(csv_path):
    """Load stations CSV and upsert into maestro.stations with EPSG:2154 geometry."""
    df = pd.read_csv(csv_path, dtype={"campaign": str, "name": str})
    # Basic cleanup
    df["campaign"] = df["campaign"].str.strip()
    df["name"] = df["name"].str.strip()
    df["lon"] = df["lon"].apply(safe_float)
    df["lat"] = df["lat"].apply(safe_float)
    df["range_m"] = df["range_m"].astype(int)

    # Remove rows missing required bits
    df = df[~df["campaign"].isna() & ~df["name"].isna()]

    # --- Option A (recommended): reprojection IN DATABASE (assumes lon/lat are EPSG:4326) ---
    rows = df.to_dict(orient="records")
    upsert_sql = text("""
        INSERT INTO maestro.stations (campaign, name, geom, range_m)
        VALUES (
            :campaign,
            :name,
            CASE
                WHEN :lon IS NULL OR :lat IS NULL THEN NULL
                ELSE ST_Transform(ST_SetSRID(ST_MakePoint(:lon, :lat), 4326), 2154)
            END,
            :range_m
        )
        ON CONFLICT (campaign) DO UPDATE
        SET name = EXCLUDED.name,
            geom = COALESCE(EXCLUDED.geom, maestro.stations.geom);
    """)

    with engine.begin() as conn:
        conn.execute(upsert_sql, rows)

def load_quarter_excel(filepath):
    """Read and normalize one Excel file."""
    df = pd.read_excel(filepath)

    # Normalize headers once
    df = df.rename(columns={
        "Campaigns.Name": "campaigns_name",
        "Start (local)": "start_local",
        "End (local)": "end_local",
        "MaxTimeStamp (local)": "maxts_local",
        "Type Avion": "type_avion",
        "Numéro de vol": "flight_number",
        "Duration (s)": "duration_s",
        "Direction": "direction",
        "Alt": "alt",
        "Alt_m": "alt_m",
        "Laeq": "laeq",
        "Sel": "sel",
        "LaMax1S": "lamax1s",
        "Precipitation": "precipitation",
        "WindSpeed": "windspeed",
        "Humidity": "humidity"
    })

    # Split Campaigns.Name into campaign (Fxxx) and station name
    df["campaign"] = df["campaigns_name"].astype(str).str.extract(r'^(F\d+)')
    df["station_name"] = df["campaigns_name"].astype(str).str.replace(r'^(F\d+)\s*', '', regex=True)

    # Parse datetimes (format: dd/mm/YYYY HH:MM:SS)
    for col in ["start_local", "end_local", "maxts_local"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], format="%d/%m/%Y %H:%M:%S", errors="coerce")

    # Keep only columns we need for the fact table
    cols = [
        "campaign", "start_local", "end_local", "maxts_local",
        "type_avion", "flight_number", "duration_s", "direction",
        "alt", "alt_m", "laeq", "sel", "lamax1s", "precipitation",
        "windspeed", "humidity", "station_name"
    ]
    for c in cols:
        if c not in df.columns:
            df[c] = pd.NA

    # Drop rows with no campaign or no start/end time
    df = df[~df["campaign"].isna()]
    return df[cols]

def upsert_station_names_from_excels(df):
    """If station names in Excel differ, keep the latest non-null name per campaign."""
    # Build latest mapping {campaign: last seen station_name}
    name_map = (df[["campaign", "station_name"]]
                .dropna()
                .drop_duplicates(subset=["campaign"], keep="last")
                .to_dict(orient="records"))
    if not name_map:
        return
    sql = text("""
        UPDATE maestro.stations s
        SET name = v.station_name
        FROM (VALUES
            -- rows injected by Python
            -- (:campaign, :station_name), ...
            -- SQLAlchemy will expand
        ) AS v(campaign, station_name)
        WHERE s.campaign = v.campaign
          AND v.station_name IS NOT NULL
          AND v.station_name <> s.name;
    """)
    # SQLAlchemy can't expand VALUES from dicts directly; do manual execute-many:
    with engine.begin() as conn:
        conn.execute(
            text("/* noop to keep connection open */ SELECT 1")
        )
        # Build one UPDATE per row to keep it simple & safe
        upd = text("""
            UPDATE maestro.stations
            SET name = :station_name
            WHERE campaign = :campaign AND :station_name IS NOT NULL AND :station_name <> name
        """)
        conn.execute(upd, name_map)

def insert_measurements(df):
    fact_cols = [
        "campaign", "start_local", "end_local", "maxts_local",
        "type_avion", "flight_number", "duration_s", "direction",
        "alt", "alt_m", "laeq", "sel", "lamax1s", "precipitation",
        "windspeed", "humidity"
    ]
    df_fact = df[fact_cols].copy()

    # Optional: coerce numerics
    for c in ["duration_s", "alt", "alt_m", "laeq", "sel", "lamax1s", "windspeed", "humidity"]:
        if c in df_fact.columns:
            df_fact[c] = pd.to_numeric(df_fact[c], errors="coerce")

    # Insert (append)
    df_fact.to_sql("noise_measurements", engine, schema="maestro",
                   if_exists="append", index=False, method="multi", chunksize=10_000)

def run_pipeline():
    run_ddl()

    # 1) Stations first (CSV with lon/lat)
    print(f"Loading stations from {STATIONS_CSV} ...")
    load_stations_csv(STATIONS_CSV)

    # 2) Then quarterly Excel files
    files = sorted(glob.glob(os.path.join(EXCEL_DIR, "*.xlsx")))
    if not files:
        print("No Excel files found.")
        return

    for f in files:
        print(f"Processing {f} ...")
        df = load_quarter_excel(f)

        # If Excel carried a more current station name, update it
        upsert_station_names_from_excels(df)

        # Fact inserts
        insert_measurements(df)

    print("Done.")

if __name__ == "__main__":
    run_pipeline()
