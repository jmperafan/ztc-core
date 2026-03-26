# Python Models

## The problem

SQL is the right tool for most data transformations, but it has hard limits. Some things are simply not expressible — or are impractically complex — in SQL:

| Issue | Example |
| --- | --- |
| **Missing statistical functions** | Snowflake has no native `MEDIAN()` aggregate — computing it requires a window function workaround |
| **No ML primitives** | Clustering, forecasting, and dimensionality reduction cannot be done in SQL |
| **Painful iteration** | Complex transformations that are natural in Python (cross-joins, vectorised operations) become multi-CTE SQL that is hard to read and debug |
| **Package ecosystem** | scikit-learn, Polars, statsmodels, and hundreds of other libraries are unavailable in SQL |

dbt Python models solve this by letting you write a model as a Python function. The function runs inside Snowflake using Snowpark, and the result is materialised as a table — part of the same DAG as your SQL models, with the same `ref()` lineage, tests, and documentation.

---

## How Python models work

A Python model is a `.py` file in your `models/` directory. It must define a `model(dbt, session)` function that returns a Snowpark DataFrame.

```python
# models/marts/my_python_model.py

def model(dbt, session):
    # 1. Configure the model
    dbt.config(materialized="table", packages=["pandas"])

    # 2. Load upstream models with dbt.ref() — same as {{ ref() }} in SQL
    df = dbt.ref("my_upstream_model").to_pandas()

    # 3. Transform using Python
    result = df.groupby("category")["value"].sum().reset_index()

    # 4. Return a Snowpark DataFrame
    return session.create_dataframe(result)
```

The four parts are always the same: **config → load → transform → return**.

---

## The `dbt.config()` call

```python
dbt.config(
    materialized="table",       # "table" or "incremental" — views are not supported
    packages=["polars"],        # installed from Snowflake's Anaconda channel at runtime
    tags=["python", "ml"],      # same tag system as SQL models
)
```

**Packages** are pulled from [Snowflake's curated Anaconda channel](https://repo.anaconda.com/pkgs/snowflake/) at runtime. You cannot install arbitrary PyPI packages — only what Snowflake has whitelisted. Available packages include `pandas`, `polars`, `scikit-learn`, `numpy`, `statsmodels`, and many others.

**Materialization** is limited to `table` and `incremental`. Views are not supported for Python models because the Python function must execute and produce rows — it cannot be lazily evaluated like a SQL view.

---

## Loading data with `dbt.ref()` and `dbt.source()`

```python
# Reference another dbt model
df = dbt.ref("fct_reservations")

# Reference a raw source
df = dbt.source("ztc", "court_usage")
```

Both return a **Snowpark DataFrame** — a lazy reference to the table in Snowflake. No data is pulled into memory yet.

To work with the data in Python, convert it:

```python
# Pandas — simple, widely known
pdf = dbt.ref("fct_reservations").to_pandas()

# Polars via Arrow — faster than pandas, avoids an extra data copy
import polars as pl
pldf = pl.from_arrow(dbt.ref("fct_reservations").to_arrow())
```

`.to_pandas()` is the most compatible option. `.to_arrow()` + `pl.from_arrow()` is preferred when working with Polars because it skips an intermediate copy.

---

## Returning results

`model()` must return a **Snowpark DataFrame**. If your transformation produces a Pandas or Polars DataFrame, convert it back before returning:

```python
# From Pandas
return session.create_dataframe(pandas_df)

# From Polars (requires .to_pandas() as an intermediate step —
# Snowpark has no direct Polars or Arrow intake)
return session.create_dataframe(polars_df.to_pandas())
```

---

## Pandas vs Polars

This project uses **Polars** for the analytical Python models and **Pandas** in the introductory example.

| | Pandas | Polars |
| --- | --- | --- |
| **Familiarity** | Industry standard, widely known | Growing fast, more expressive API |
| **Performance** | Slower on large DataFrames | Significantly faster; lazy evaluation |
| **Style** | Imperative, method-chaining | Functional, expression-based, `pipe()`-friendly |
| **Arrow conversion** | `.to_arrow()` / `pd.read_feather()` | Native Arrow support via `pl.from_arrow()` |
| **Availability in Snowflake** | Yes | Yes (Anaconda channel) |

For new models, prefer **Polars**. The expression-based API (`pl.col()`, `pl.when().then()`) is more readable for data engineers, and the Arrow-based I/O avoids unnecessary copies.

---

## Python models in this project

This project has three Python models, all in `models/marts/`.

---

### `python_court_stats` — introductory example

**Purpose:** Demonstrates the basic shape of a dbt Python model. Computes descriptive statistics on reservation duration per court.

**Why Python?** Snowflake SQL has no native `MEDIAN()` aggregate function. This is the simplest realistic justification for a Python model in this project.

```python
stats = (
    df.group_by("COURT_NUMBER")
    .agg(
        pl.col("DURATION_IN_MINS").mean().alias("avg_duration_mins"),
        pl.col("DURATION_IN_MINS").median().alias("median_duration_mins"),
        pl.col("DURATION_IN_MINS").std().alias("std_duration_mins"),
        pl.len().alias("total_reservations"),
    )
)
```

**Output:** One row per court with average, median, standard deviation, and count of duration.

---

### `python_member_segments` — K-means clustering

**Purpose:** Clusters club members into behavioural segments based on their booking history.

**Why Python?** K-means clustering is not expressible in SQL. It requires iterative distance calculations across a feature matrix — a natural fit for scikit-learn.

**How it works:**

1. **Load** reservations, bridge table, and member dimension
2. **Feature engineering** — one row per member with five features:
   - Total bookings
   - Average duration
   - Average start hour
   - Weekend ratio (share of bookings on Sat/Sun)
   - Number of distinct courts used
3. **Scale** features with `StandardScaler` (required for distance-based algorithms)
4. **Cluster** with `KMeans(n_clusters=4)`
5. **Label** each cluster heuristically from its centroid characteristics

**Output segments:** Casual Player, Weekend Player, Frequent Morning Player, Frequent Evening Player.

**Packages:** `polars`, `scikit-learn`

---

### `python_demand_forecast` — utilization forecasting

**Purpose:** Produces a 30-day ahead forecast of court utilization per court.

**Why Python?** Time-series forecasting with trend adjustment requires vectorised operations across rolling windows and cross-join grids — extremely verbose in SQL, natural in Polars.

**How it works:**

1. **Load** `fct_court_usage`, filter out winter breaks and closed hours
2. **Aggregate** to daily utilization per court (booked mins / 900 available mins)
3. **Baseline** — average utilization by court × day-of-week
4. **Trend** — ratio of last 28 days mean to overall mean, clipped to [0.5, 1.5]
5. **Grid** — cross-join of courts × future dates (no Python loop)
6. **Predict** — `dow_avg × trend_factor × seasonal_factor`, clipped to [0, 1]

Monthly seasonal multipliers encode the lower outdoor usage typical of Dutch winters (lower values for Jan/Feb/Nov/Dec).

**Output:** One row per court × forecast date with `predicted_utilization_rate`.

**Packages:** `polars`

---

## Limitations

| Limitation | Detail |
| --- | --- |
| **dbt Fusion** | dbt Fusion (dbt Cloud's newer runtime) does not currently support Python models. These models run on **dbt Core + dbt-snowflake** only. |
| **No `var()` access** | Python models cannot call `dbt.var('my_var')` the way SQL models use `{{ var() }}`. Values like `opening_hour` and `closing_hour` are defined as module-level constants instead. |
| **Table only** | Python models cannot be materialised as views or as ephemeral models — only `table` and `incremental` are supported. |
| **Package constraints** | Only packages available in Snowflake's Anaconda channel can be installed. No arbitrary PyPI packages. |
| **Snowpark execution** | The Python code runs inside Snowflake's Snowpark runtime, not locally. Local IDE linting warnings about unresolved imports (e.g. `polars`) are expected and harmless — the packages are installed at runtime. Memory and execution time are subject to Snowflake's platform limits. |
| **Adapter support** | Python models are only supported on Snowflake, Databricks, and BigQuery. Most other dbt adapters do not support them. |
| **One output per model** | A Python model must return exactly one DataFrame. You cannot produce multiple output tables from a single model. |
| **No Python for non-model resources** | Tests, snapshots, and analyses must be written in SQL. Python is only supported for models. |
| **Performance vs SQL** | Python models are generally slower than equivalent SQL models — data must be serialised and processed outside the SQL engine. The Polars `to_pandas()` round-trip before returning to Snowpark adds overhead on large datasets. Use Python only where SQL genuinely cannot do the job. |

---

## Tips and tricks

### Keep `model()` thin — extract logic into plain functions

dbt only calls `model()`, but nothing stops you from defining helper functions in the same file. This project does it throughout: `load_usage()`, `daily_utilization()`, `dow_baselines()`, etc. are all plain Python functions that take and return DataFrames. `model()` just orchestrates them.

Benefits:

- Each function is independently testable outside dbt
- `.pipe()` chains read like a pipeline: `load_usage(dbt).pipe(daily_utilization)`
- Easier to reuse logic if you split a model later

### Define constants at module level

Configuration values that would normally be dbt variables (`opening_hour`, `closing_hour`, forecast horizon) can live as module-level constants. This project uses `OPENING_HOUR`, `CLOSING_HOUR`, `AVAILABLE_MINS`, `FORECAST_HORIZON`, and `SEASONAL_FACTORS` at the top of the file — outside `model()`. They're immediately visible, easy to change, and don't require a Snowflake connection to inspect.

### Use Arrow as the I/O bridge, not Pandas

When using Polars, prefer `.to_arrow()` over `.to_pandas()` when loading from Snowpark:

```python
# Slower — two copies: Snowpark → Pandas → Polars
df = pl.from_pandas(dbt.ref("my_model").to_pandas())

# Faster — one copy: Snowpark → Arrow → Polars
df = pl.from_arrow(dbt.ref("my_model").to_arrow())
```

You still need `.to_pandas()` on the way back out (`session.create_dataframe(polars_df.to_pandas())`), because Snowpark has no direct Polars intake. That round-trip is unavoidable, but at least the inbound path is efficient.

### Rename columns to uppercase before returning

Snowflake normalises unquoted column names to uppercase. If you return lowercase column names from a Python model, downstream SQL `ref()`s will break because Snowflake will uppercase them inconsistently. Rename explicitly before returning:

```python
result = result.rename({col: col.upper() for col in result.columns})
return session.create_dataframe(result.to_pandas())
```

All three Python models in this project do this.

### Set `random_state` on any non-deterministic algorithm

ML models like KMeans produce different cluster assignments on every run unless you fix the seed. This causes schema-level instability (segment labels flip between runs) which breaks downstream models and tests. Always set `random_state=42` (or any fixed integer):

```python
KMeans(n_clusters=4, random_state=42, n_init=10).fit_predict(X_scaled)
```

### Push filtering upstream, not downstream

Python models are expensive to run. Minimise the data that crosses the Snowpark→Python boundary by filtering as early as possible — ideally in an upstream SQL model, or at least as the first operation after `dbt.ref()`:

```python
# Good — filter before any Python work
df = (
    pl.from_arrow(dbt.ref("fct_court_usage").to_arrow())
    .filter(pl.col("IS_WINTER_BREAK").cast(pl.Boolean).not_())
)
```

---

## Running Python models locally

Python models require a live Snowflake connection and a `dbt-snowflake` profile:

```bash
# Run a single Python model
dbt run --select python_court_stats

# Run all Python models
dbt run --select tag:python

# Run and test
dbt build --select tag:python
```

Because the Python code executes inside Snowflake (not on your machine), there is no way to run it fully offline. Use `dbt compile --select python_court_stats` to validate that dbt can parse the model — this does not require a warehouse connection.
