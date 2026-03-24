"""
Load raw source data into Snowflake, anonymizing club_members PII before upload.

Requires:
    pip install snowflake-connector-python pandas openpyxl

Environment variables (set these before running):
    SNOWFLAKE_ACCOUNT   - e.g. xy12345.us-east-1
    SNOWFLAKE_USER      - your Snowflake username
    SNOWFLAKE_PASSWORD  - your Snowflake password
    SNOWFLAKE_ROLE      - (optional) defaults to SYSADMIN
    SNOWFLAKE_DATABASE  - (optional) defaults to ZTC_COURT_USAGE
    SNOWFLAKE_WAREHOUSE - your Snowflake warehouse name
"""

import os
import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
USER = os.environ["SNOWFLAKE_USER"]
PASSWORD = os.environ["SNOWFLAKE_PASSWORD"]
ROLE = os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN")
DATABASE = os.environ.get("SNOWFLAKE_DATABASE", "ZTC_COURT_USAGE")
WAREHOUSE = os.environ["SNOWFLAKE_WAREHOUSE"]
SCHEMA = "RAW"

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "input")

# Columns to remove from club_members (PII)
PII_COLUMNS = [
    "Voorletters",
    "Voornaam",
    "Tussenvoegsel",
    "Achternaam",
    "Primair e-mailadres",
    "Overige e-mailadressen",
    "Straatnaam",
    "Huisnr.",
    "Toevoeging",
    "Bondsnummer",  # national federation ID — traceable externally
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def get_connection():
    return snowflake.connector.connect(
        account=ACCOUNT,
        user=USER,
        password=PASSWORD,
        role=ROLE,
        warehouse=WAREHOUSE,
    )


def setup_database(cur):
    print(f"Setting up {DATABASE}.{SCHEMA}...")
    cur.execute(f"USE DATABASE {DATABASE}")
    cur.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")
    cur.execute(f"USE SCHEMA {SCHEMA}")


def sanitize_col(name: str) -> str:
    """Uppercase and replace any non-alphanumeric characters with underscores."""
    import re
    name = str(name).upper()
    name = re.sub(r'[^A-Z0-9]+', '_', name)
    return name.strip('_')


def upload_table(conn, df: pd.DataFrame, table_name: str):
    """Write a DataFrame to Snowflake, replacing the table if it exists."""
    df.columns = [sanitize_col(c) for c in df.columns]
    print(f"  Uploading {len(df):,} rows → {DATABASE}.{SCHEMA}.{table_name}...")
    success, nchunks, nrows, _ = write_pandas(
        conn,
        df,
        table_name=table_name,
        database=DATABASE,
        schema=SCHEMA,
        auto_create_table=True,
        overwrite=True,
        quote_identifiers=False,
    )
    if success:
        print(f"  Done: {nrows:,} rows in {nchunks} chunk(s).")
    else:
        raise RuntimeError(f"Failed to upload {table_name}")


# ---------------------------------------------------------------------------
# Load data
# ---------------------------------------------------------------------------
def load_court_usage(conn):
    print("Loading court_usage...")
    df_2023 = pd.read_csv(
        os.path.join(DATA_DIR, "court_usage_2023.csv"),
        encoding="utf-8-sig",
    )
    df_2024 = pd.read_excel(os.path.join(DATA_DIR, "court_usage_2024.xlsx"))
    df = pd.concat([df_2023, df_2024], ignore_index=True)
    upload_table(conn, df, "COURT_USAGE")


def load_club_members(conn):
    print("Loading club_members (anonymized)...")
    df = pd.read_csv(
        os.path.join(DATA_DIR, "club_members.csv"),
        sep=";",
        encoding="utf-8-sig",
    )
    # Remove PII columns
    cols_to_drop = [c for c in PII_COLUMNS if c in df.columns]
    df = df.drop(columns=cols_to_drop)
    print(f"  Removed PII columns: {cols_to_drop}")
    upload_table(conn, df, "CLUB_MEMBERS")


def load_weather_data(conn):
    print("Loading weather_data...")
    weather_csv = os.path.join(DATA_DIR, "weather_data", "weather_data.csv")
    df = pd.read_csv(weather_csv)
    upload_table(conn, df, "WEATHER_DATA")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            setup_database(cur)
        load_court_usage(conn)
        load_club_members(conn)
        load_weather_data(conn)
        print("\nAll tables loaded successfully.")
    finally:
        conn.close()
