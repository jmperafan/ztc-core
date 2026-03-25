# Source Freshness

## The problem

Data pipelines break silently. A source table stops updating — the ingestion job fails, the upstream system changes, or a permission expires — and nobody notices. Dashboards keep loading, reports keep running, and stakeholders keep making decisions based on numbers that are days or weeks out of date.

| Issue | Example |
| --- | --- |
| **Silent staleness** | The weather source hasn't refreshed in 36 hours; the ideal-weather metric is calculated on yesterday's data |
| **No alerting** | Nobody knows the court_usage table stopped updating until a stakeholder notices the numbers look wrong |
| **Manual checking** | Someone has to query `MAX(loaded_at)` on each source table to verify freshness — this doesn't scale |
| **No ownership** | Freshness expectations live in a Confluence page nobody reads, not in the project itself |

Source freshness checks solve this by encoding expectations about recency directly into the dbt project — tested on every run, visible in the dbt docs, and alertable through dbt Cloud.

---

## How it works

dbt source freshness compares the maximum value of a `loaded_at_field` column against the current timestamp. If the difference exceeds a threshold, the check warns or errors.

Two things are required per source table:

1. **`loaded_at_field`** — the column that represents when a row was last loaded or created. This must be a timestamp or date column in the raw table.
2. **`freshness`** — the thresholds. Two levels are available:
   - `warn_after`: raises a warning but does not fail the run
   - `error_after`: fails the run and blocks downstream jobs

---

## Configuration in this project

> **Note:** dbt Fusion does not currently support the `loaded_at_field` / `freshness` syntax at the table level in `_sources.yml`. If you are running on dbt Core, add freshness checks as shown below. On dbt Fusion, use the dbt Cloud UI or wait for freshness support to land in the Fusion runtime.

```yaml
# models/staging/_sources.yml (dbt Core syntax)

sources:
  - name: ztc
    database: RAW
    schema: ZTC
    tables:
      - name: court_usage
        freshness:
          loaded_at_field: startdatum
          warn_after: {count: 7, period: day}
          error_after: {count: 14, period: day}

      - name: club_members
        # No freshness check — no reliable timestamp column in this table

      - name: weather_data
        freshness:
          loaded_at_field: datetime
          warn_after: {count: 24, period: hour}
          error_after: {count: 48, period: hour}
```

### Why these thresholds?

**`court_usage`** uses `startdatum` (the reservation date) as the freshness signal. Reservations are made continuously, so if the most recent `startdatum` is more than 7 days old, something is likely wrong with the ingestion. A 14-day error threshold gives time to investigate without silently running stale for weeks.

**`weather_data`** uses `datetime` (hourly timestamps). Weather data should refresh daily; a 24-hour warning and 48-hour error catches missed refreshes quickly.

**`club_members`** has no reliable ingestion timestamp in the raw table. The freshness check is omitted entirely rather than leaving it undefined.

---

## Running the check

```bash
# Check all sources
dbt source freshness

# Check a specific source
dbt source freshness --select source:ztc

# Check a specific table
dbt source freshness --select source:ztc.weather_data
```

Output example:
```
Found 3 sources (2 with freshness checks)

12:04:23  Freshness checks [OK in 1.34s]
  court_usage     OK [max_loaded_at=2024-12-15 | age=2 days, 14 hours | warn after 7 days]
  weather_data    OK [max_loaded_at=2024-12-16 08:00 | age=4 hours | warn after 24 hours]
```

---

## In CI/CD

Source freshness can be run as a separate step in the CI pipeline, before `dbt build`. This catches stale data before it propagates into models.

```yaml
# .github/workflows/dbt.yml (excerpt)
- name: Check source freshness
  run: dbt source freshness

- name: Build models
  run: dbt build
```

In dbt Cloud, source freshness results appear in the run history UI and can trigger alerts via Slack or email when thresholds are breached.

---

## Trade-offs

| Consideration | Detail |
| --- | --- |
| **Requires a timestamp column** | If the raw table has no reliable loaded-at column, freshness cannot be measured. Some sources need an ingestion timestamp added at the ETL layer. |
| **`loaded_at_field` is not always load time** | Using a business date (like `startdatum`) is a proxy — it tells you the recency of the data, not when it was loaded. A booking made far in the future will look "fresh" even if ingestion has stopped. |
| **False positives on low-volume sources** | A table that only receives rows on weekdays will trigger a freshness error every Monday morning. Thresholds should account for expected update cadence. |
