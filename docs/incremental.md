# Incremental Models

## The problem

Most models in this project are materialised as **tables** — dbt drops and rebuilds the entire table on every run. For small or medium datasets this is fine. As data grows, full rebuilds become expensive.

Consider `fct_court_usage`: it is one row per minute per court, covering all courts from 2022 to today. Every day that passes adds `5 courts × 15 hours × 60 minutes = 4,500 rows`. A full rebuild processes all history on every run, even though only the newest dates have changed.

Incremental models solve this by processing only the **new or changed rows** on each run. The first run builds the full table from scratch; every subsequent run appends or merges a small slice on top.

---

## How incremental models work

A model is made incremental by setting `materialized='incremental'` in its config block:

```sql
{{ config(materialized='incremental', unique_key='my_key') }}

SELECT ...
FROM {{ ref('my_upstream_model') }}

{% if is_incremental() %}
    WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

Two pieces make this work:

### `is_incremental()`

A Jinja macro provided by dbt that evaluates to `TRUE` only during incremental runs (i.e. when the target table already exists and `--full-refresh` has not been passed). Wrap your date filter in this macro so that the first run — which must process everything — does not apply the filter.

```sql
{% if is_incremental() %}
    -- This block is skipped on the first run and on --full-refresh runs.
    AND reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}
```

### `{{ this }}`

A Jinja reference to the model's own table in the warehouse. Using `SELECT MAX(...) FROM {{ this }}` inside `is_incremental()` is the standard pattern for "give me only what is newer than what I already have".

---

## Incremental strategies

The `incremental_strategy` config tells dbt how to merge new rows into the existing table. The right choice depends on whether your source data can change after it is first written.

| Strategy | What dbt does | Best when |
| --- | --- | --- |
| `append` | `INSERT` new rows — no deduplication | Source is strictly append-only; duplicate rows are impossible |
| `delete+insert` | `DELETE` existing rows matching `unique_key`, then `INSERT` | Data arrives in date-partitioned batches; occasional re-delivery of a full date is possible |
| `merge` | SQL `MERGE` — upsert row-by-row on `unique_key` | Rows can be individually corrected after the fact; late-arriving updates at sub-day granularity |
| `microbatch` | Processes one time-window at a time; dbt injects the filter automatically | Event-stream data at known time granularity; need resilient partial retries per batch |

Snowflake supports all four strategies via the `dbt-snowflake` adapter. `microbatch` requires dbt 1.9+.

### `unique_key`

Required for `delete+insert` and `merge`. Identifies which column(s) uniquely identify a row. For `delete+insert` a single column is typical; for `merge` you can pass a list:

```sql
-- Single column
unique_key='daily_court_key'

-- Composite key (list of columns)
unique_key=['reservation_date', 'start_hour', 'court_number']
```

---

## Microbatch

Microbatch is a specialised incremental strategy introduced in dbt 1.9. Instead of writing a filter yourself with `is_incremental()`, you declare an `event_time` column and a `batch_size`, and dbt processes the data one batch at a time — automatically injecting the time-window filter for each batch.

### How it differs from regular incremental

| | Regular incremental | Microbatch |
| --- | --- | --- |
| **Filter** | You write `{% if is_incremental() %}` | dbt injects `WHERE event_time >= batch_start AND event_time < batch_end` |
| **Granularity** | One run processes everything new | Each batch is one time window (hour / day / month / year) |
| **Retry** | Failed run must reprocess everything | Failed batch can be retried in isolation |
| **Idempotent** | Depends on strategy | Yes — re-running a batch replaces only that window |
| **`unique_key`** | Required for delete+insert / merge | Not needed — time partitioning handles deduplication |

### Config options

```sql
{{
  config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='reservation_date',  -- column that defines the batch window
    batch_size='day',               -- 'hour', 'day', 'month', or 'year'
    lookback=3,                     -- reprocess last 3 completed batches on every run
    begin='2022-01-01'              -- earliest date to process on the first run
  )
}}
```

| Option | Required | Description |
| --- | --- | --- |
| `event_time` | Yes | Column dbt uses to partition batches. Must be a DATE or TIMESTAMP. |
| `batch_size` | Yes | Granularity of each batch: `hour`, `day`, `month`, or `year`. |
| `begin` | Yes | Earliest batch start date. Prevents processing records before the project existed. |
| `lookback` | No | Number of completed batches to reprocess on each run. Protects against late-arriving data. Defaults to 1. |

### No `is_incremental()` required

The SQL body of a microbatch model is written exactly like a full table build. dbt wraps it in a time filter automatically — you never write the filter yourself. This makes the SQL easier to read and test:

```sql
-- Regular incremental — filter is manual and conditional
SELECT * FROM {{ ref('fct_reservations') }}
{% if is_incremental() %}
    WHERE reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}

-- Microbatch — no filter needed; dbt injects it at run time
SELECT * FROM {{ ref('fct_reservations') }}
```

### Retrying a specific batch

If a batch fails or you need to reprocess a specific date range, pass `--event-time-start` and `--event-time-end`:

```bash
# Reprocess a single day
dbt run --select fct_reservation_events \
  --event-time-start 2024-11-01 \
  --event-time-end   2024-11-02

# Reprocess a full month
dbt run --select fct_reservation_events \
  --event-time-start 2024-11-01 \
  --event-time-end   2024-12-01
```

---

## Incremental models in this project

This project has three incremental models, all in `models/marts/`. They illustrate the three most common strategies.

---

### `fct_daily_court_stats` — delete+insert

**Purpose:** Daily aggregation of court usage per court. Booked minutes, available minutes, total playable slots, and utilization percentage — one row per court × date.

**Why incremental?** The upstream `fct_court_usage` spans years of minute-level slots. Recomputing daily aggregates for all history on every run is wasteful — only today's date changes.

**Strategy: `delete+insert`**

```sql
{{
  config(
    materialized='incremental',
    unique_key='daily_court_key',
    incremental_strategy='delete+insert',
    on_schema_change='fail'
  )
}}
```

`delete+insert` works well here because the natural unit of reprocessing is a full date. If source data for a past date is corrected and re-loaded, you can trigger a `--full-refresh` or adjust the lookback window to reprocess that date cleanly.

**Incremental filter:**

```sql
{% if is_incremental() %}
    AND reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}
```

Only dates beyond the maximum already in the table are processed. Combined with `delete+insert`, this means any partial load for today's date is replaced in full.

---

### `fct_hourly_weather_usage` — merge

**Purpose:** Hourly usage per court joined with weather observations (temperature, precipitation, wind speed, ideal weather flag). One row per court × date × hour.

**Why incremental?** The weather API delivers hourly data, and corrections can arrive hours or even days after the initial observation. A pure append strategy would miss those corrections; `merge` applies them automatically on the next run.

**Strategy: `merge`**

```sql
{{
  config(
    materialized='incremental',
    unique_key=['reservation_date', 'start_hour', 'court_number'],
    incremental_strategy='merge',
    on_schema_change='fail'
  )
}}
```

The composite `unique_key` matches the natural grain: one row per court per hour per date. If a corrected weather reading arrives for a past hour, the next run upserts it in place.

**Incremental filter:**

```sql
{% if is_incremental() %}
    AND reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}
```

The filter is applied inside `hourly_usage` before the join. Weather is joined via `LEFT JOIN` so that hours with no weather data still appear in the output — `ideal_weather` and the numeric columns are simply NULL for those rows.

---

### `fct_reservation_events` — microbatch

**Purpose:** One row per actual booking, enriched with member demographics (gender, age group, city, membership type). Adds day-of-week and start-hour for easy slicing without downstream date functions.

**Why incremental?** Bookings are immutable events — once a court is reserved, the reservation record does not change. New bookings arrive every day. Microbatch is a natural fit: each day's batch is small, self-contained, and independently reprocessable.

**Why microbatch over delete+insert?** No filter to maintain. If a date's data is reprocessed (e.g., a member's profile is corrected), re-running the affected batch with `--event-time-start` / `--event-time-end` is cleaner than managing a manual lookback expression. The `lookback=3` config also automatically reprocesses the last three days on every run, protecting against late-arriving source data.

**Config:**

```sql
{{
  config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='reservation_date',
    batch_size='day',
    lookback=3,
    begin='2022-01-01',
    on_schema_change='fail'
  )
}}
```

**SQL (no filter needed):**

```sql
SELECT
    r.reservation_id,
    r.reservation_date,   -- this is the event_time column
    r.court_number,
    r.start_time,
    r.end_time,
    r.duration_in_mins,
    r.day_of_week,
    r.day_of_week_name,
    r.start_hour,
    b.member_id,
    p.gender,
    p.age_group,
    ...
FROM reservations r
LEFT JOIN member_bridge b  ON r.reservation_id = b.reservation_id
LEFT JOIN member_profiles p ON b.member_id     = p.member_id
```

dbt automatically appends `WHERE reservation_date >= <batch_start> AND reservation_date < <batch_end>` to the innermost CTE that references `fct_reservations`. The SQL itself contains no time filter.

---

## Choosing a lookback window

The pattern `reservation_date > MAX(reservation_date)` only processes strictly new dates. If late-arriving data for the current date is possible, use `>=` instead:

```sql
{% if is_incremental() %}
    AND reservation_date >= (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}
```

This reprocesses the most recent date on every run — a small extra cost that protects against partial loads. Combine this with `delete+insert` to avoid duplicates.

For longer lookback windows (e.g., reprocess the last 3 days to catch late corrections):

```sql
{% if is_incremental() %}
    AND reservation_date >= DATEADD('day', -3, (SELECT MAX(reservation_date) FROM {{ this }}))
{% endif %}
```

---

## `on_schema_change`

Controls what happens when the SQL produces different columns than the existing table:

| Value | Behaviour |
| --- | --- |
| `fail` (default) | Raise an error — safest; forces intentional schema changes |
| `ignore` | Silently ignore new or removed columns — risky; can produce silent data gaps |
| `append_new_columns` | Add new columns to the table; do not remove deleted ones |
| `sync_all_columns` | Add new columns and remove deleted ones — closest to a full rebuild |

Both models in this project use `on_schema_change='fail'`. If you need to add a column, run `dbt run --full-refresh --select <model_name>` to rebuild the table from scratch, then resume incremental runs.

---

## Full refresh

Pass `--full-refresh` to force a complete rebuild regardless of incremental state:

```bash
# Rebuild a single incremental model from scratch
dbt run --full-refresh --select fct_daily_court_stats

# Rebuild all incremental models
dbt run --full-refresh --select config.materialized:incremental
```

Use `--full-refresh` when:
- You change the SQL logic in a way that affects historical rows
- You add, rename, or remove columns (`on_schema_change='fail'` will otherwise block the run)
- The incremental filter has drifted and you want to reprocess everything cleanly

---

## Limitations

| Limitation | Detail |
| --- | --- |
| **First run cost** | The first run (or any `--full-refresh`) processes all history. This is identical in cost to a regular table build. |
| **`is_incremental()` is false in CI** | In a fresh CI environment the target table does not exist, so `is_incremental()` always evaluates to `FALSE`. CI runs are always full builds. |
| **No time travel** | The `MAX(date) FROM {{ this }}` pattern has no memory beyond the most recent row. If source data is corrected for a date that is not the maximum, those corrections are silently missed unless you use a longer lookback window or `--full-refresh`. |
| **Strategy support varies by adapter** | `delete+insert` and `merge` require adapter support. Both are supported by `dbt-snowflake`. Check the dbt docs for other warehouses. |
| **Contracts and incremental** | Contracts (`contract: {enforced: true}`) can be combined with incremental materialisation. The contract is enforced on every run, including the incremental ones. |
| **Python models** | Python models support `incremental` materialisation, but the `is_incremental()` macro is not available inside `.py` files. Implement the filter logic manually using the Snowpark session. |
| **Microbatch requires dbt 1.9+** | The `microbatch` strategy was introduced in dbt Core 1.9. Earlier versions will fail to parse the config. |
| **Microbatch and `is_incremental()`** | `is_incremental()` always returns `FALSE` inside a microbatch model — dbt manages the filter itself. Do not mix the two patterns. |
| **Microbatch event_time must be in SELECT** | The `event_time` column must be present in the model's output. If it is absent dbt will raise a parse error. |
| **Microbatch run time scales with batch count** | On a fresh build (or `--full-refresh`), dbt issues one query per batch from `begin` to today. A two-year history at `batch_size='day'` means ~730 queries. Use `batch_size='month'` if daily granularity is not required. |
