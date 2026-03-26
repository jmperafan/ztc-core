import polars as pl


def model(dbt, session):
    # 1. CONFIG
    # Tell dbt how to materialise this model and which packages to install.
    # Packages are pulled from Snowflake's Anaconda channel at runtime.
    dbt.config(
        materialized="table",
        packages=["snowflake-snowpark-python", "polars"],
        tags=["python", "example"],
    )

    # 2. LOAD
    # dbt.ref() works exactly like {{ ref() }} in SQL — it returns a Snowpark
    # DataFrame pointing at another model. .to_arrow() + pl.from_arrow() is
    # faster than .to_pandas() because it avoids an extra data copy.
    df = pl.from_arrow(dbt.ref("fct_reservations").to_arrow())

    # 3. TRANSFORM
    # This is where you do things SQL struggles with, like median.
    # Polars .agg() takes a list of named expressions — one per output column.
    stats = (
        df.group_by("COURT_NUMBER")
        .agg(
            pl.col("DURATION_IN_MINS").mean().alias("avg_duration_mins"),
            pl.col("DURATION_IN_MINS").median().alias("median_duration_mins"),
            pl.col("DURATION_IN_MINS").std().alias("std_duration_mins"),
            pl.len().alias("total_reservations"),
        )
    )

    # 4. RETURN
    # session.create_dataframe() converts a pandas DataFrame back into a
    # Snowpark DataFrame, which dbt then writes to the warehouse.
    return session.create_dataframe(stats.to_pandas())
