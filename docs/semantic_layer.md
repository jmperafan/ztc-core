# dbt Semantic Layer

## The problem

Without a semantic layer, every analyst writes their own version of the same metric. One dashboard counts reservations including cancelled bookings; another doesn't. One report calculates utilization against total hours; another against open hours only. The numbers never agree, and nobody knows which one is right.

| Issue | Example |
| --- | --- |
| **Inconsistent definitions** | "Court utilization" means different things in three different dashboards |
| **SQL copy-paste** | The same ratio logic is written 12 times across 12 notebooks; when the business rule changes, 11 of them stay wrong |
| **No governance** | There is no authoritative definition of "active member" — it depends who you ask |
| **BI-tool lock-in** | Metric logic lives inside a specific tool; switching BI tools means rewriting all the logic |

The semantic layer solves this by making metric definitions part of the dbt project — versioned, reviewed, and tested alongside the models they depend on.

---

## The toolchain

A dbt Semantic Layer implementation combines three components. Each solves a different problem.

### MetricFlow

**What it does**: MetricFlow is the metric definition engine built into dbt. You define semantic models (entities, dimensions, and measures) and metrics in YAML. MetricFlow compiles those definitions into SQL at query time, optimised for whatever grain and filters the consumer requests.

**Why it matters**: Metric definitions become code. They live in the repo, go through code review, and follow the same CI pipeline as the rest of the project. When a definition changes, the change is visible in a diff. When a consumer asks "how is this calculated?", the answer is in the YAML file.

**The trade-off**: MetricFlow YAML is an additional layer to maintain. Simple metrics are easy to define; complex ones (multi-hop joins, non-additive measures) require more care. The investment pays off when multiple teams or tools need to agree on the same numbers.

---

### dbt Semantic Layer API

**What it does**: dbt Cloud exposes the compiled metric definitions through a JDBC endpoint and a GraphQL API. Any tool that speaks JDBC — Tableau, Mode, Hex, Lightdash, Excel — can connect and query metrics without writing SQL. The query interface is metric-first: you specify which metrics you want, which dimensions to group by, and what filters to apply. MetricFlow writes the SQL.

**Why it matters**: The metric definition and the query execution are decoupled. You define utilization once; a data analyst queries it from Google Sheets, a data scientist queries it from a Jupyter notebook, and a BI developer queries it from Tableau — all hitting the same definition.

**The trade-off**: Requires a dbt Cloud Team or Enterprise plan. Not available on dbt Core or the dbt Cloud Developer plan.

---

### Google Sheets connector

**What it does**: The dbt Semantic Layer add-on for Google Sheets connects directly to the Semantic Layer API. Once configured, a sidebar lets users browse available metrics, select dimensions and filters, and populate results into the sheet with a single click. No SQL required.

**Why it matters**: Most stakeholders live in spreadsheets. The connector brings governed, consistent metrics into the tool they already use, without giving them direct warehouse access or requiring them to learn SQL. A metric defined by the data team is immediately available to the finance team, the ops team, and the board deck.

**The trade-off**: The add-on is a Google Workspace extension — it needs to be installed from the Marketplace and configured per user. Sheets are not a replacement for a proper BI tool; they are best for ad-hoc analysis and one-off reports.

---

## How it fits together

```
MetricFlow definitions (YAML in dbt project)
      │
      ▼  (dbt parse / dbt Cloud job)
      │
Compiled semantic manifest
      │
      ▼
dbt Cloud Semantic Layer API ── JDBC / GraphQL
      │
      ├── Google Sheets connector ── ad-hoc analysis, stakeholder reports
      │
      ├── Tableau / Mode / Lightdash ── BI dashboards
      │
      └── Jupyter / Hex ── data science, exploration
```

All consumers query the same definitions. The metric logic is written once.

---

## How this project implements it

### court_utilization_rate

**Semantic model**: `fct_court_usage` (core layer)

`fct_court_usage` contains one row per court-slot, covering every minute of every day in three categories: actual bookings, available-but-unbooked gaps, and closed hours. This is the right base for utilization because it carries `duration_in_mins` for every slot type.

`fct_hourly_usage` (the mart) intentionally drops `duration_in_mins` and filters out winter-break rows — it is designed for a different use case. You cannot compute a utilization ratio from it without adding columns back.

The metric is a `ratio` type:

- **Numerator** (`booked_minutes`): sum of `duration_in_mins` where `reservation_type` is not `'Beschikbaar'` (available) and not `'Gesloten'` (closed)
- **Denominator** (`available_minutes`): sum of `duration_in_mins` where `reservation_type != 'Gesloten'`

Closed hours are excluded from both numerator and denominator — you cannot book a court that is not open. Available-but-unbooked time counts only in the denominator.

The `is_winter_break` filter is applied at the metric level, not in the measure expression. This keeps the measures reusable (you could query `booked_minutes` raw, without the winter-break filter) while giving `court_utilization_rate` the right default scope.

**Why ratio type matters**: A `ratio` metric instructs MetricFlow to aggregate numerator and denominator independently before dividing. If you rolled up a pre-computed `booked / available` column across multiple courts or months, you would average averages — and get the wrong answer. The ratio type ensures the arithmetic is always correct regardless of the grouping requested.

---

### ideal_weather_hours

**Semantic model**: `fct_weather` (core layer)

The `ideal_weather` boolean in `fct_weather` is pre-computed by the `tennis_weather` macro:

```sql
temperature BETWEEN 10 AND 35
AND precipitation = 0
AND wind_speed <= 20
```

The measure sums `CAST(ideal_weather AS INTEGER)`. Snowflake booleans cannot be summed directly — the cast is required. The result is a count of hours in the dataset that met all three conditions.

This metric is most useful grouped by `metric_time__month` to show the shape of the Utrecht tennis season and understand how weather correlates with reservation patterns.

---

### total_reservations

**Semantic model**: `fct_reservations` (core layer)

`fct_reservations` contains one row per actual booking with a stable `reservation_id` primary key. This is the right base for counting reservations because there are no gap-fill rows or closed-hour rows to filter out — every row is a real booking.

`fct_court_usage` also contains reservation rows, but mixed with gap-fill rows (where `reservation_id` is NULL). Counting from `fct_reservations` is simpler and avoids any risk of counting nulls.

---

### active_members

**Semantic model**: `dim_members_anonimized` (mart layer)

Active members are defined as members where `is_club_member = TRUE`. This maps to the `clublid` field in the source data (Dutch: "club lid" = club member) and reflects current membership status as of the most recent data load.

The measure uses `COUNT_DISTINCT` with a CASE expression rather than a filter to avoid excluding rows from joins:

```sql
CASE WHEN is_club_member = TRUE THEN member_id ELSE NULL END
```

`COUNT_DISTINCT` ignores NULL values, so inactive members are excluded from the count while still being available for dimension queries.

---

## Is it worth implementing?

The Semantic Layer is high-leverage when:

- Multiple teams or tools need to agree on the same metrics
- Metric definitions need to be reviewed and versioned alongside model changes
- Stakeholders need self-serve access to governed data without warehouse access

The investment is heavier than it looks upfront — agreeing on definitions, writing the YAML, and maintaining it as models evolve. The payoff is proportional to the number of consumers. For a single analyst writing their own SQL, it adds overhead with little return. For an organisation where five teams each have their own definition of "utilization", it pays back immediately.

It requires a dbt Cloud Team or Enterprise plan. Teams on dbt Core or the Developer plan cannot use the Semantic Layer API or the Google Sheets connector.

---

## Testing locally

### Install the MetricFlow CLI

MetricFlow ships as an optional CLI alongside dbt. Install the Snowflake variant:

```bash
pip install "dbt-metricflow[snowflake]"
```

### Validate semantic model and metric definitions

`dbt parse` compiles the project without a warehouse connection and validates YAML syntax. Run this first — it's fast.

```bash
dbt parse
```

Then validate the semantic layer specifically:

```bash
mf validate-configs
```

This checks that all entities, dimensions, and measures are internally consistent, that metric references resolve, and that time dimensions are correctly configured.

### List available metrics and dimensions

```bash
# All metrics defined in the project
mf list metrics

# All dimensions available for a specific metric
mf list dimensions --metrics court_utilization_rate
mf list dimensions --metrics total_reservations
```

### Query metrics from the CLI

These commands hit the warehouse and return results in the terminal — useful for sanity-checking definitions before connecting a BI tool.

```bash
# Court utilization by month
mf query --metrics court_utilization_rate --group-by metric_time__month

# Utilization broken down by court
mf query --metrics court_utilization_rate --group-by court_number

# Total reservations per week
mf query --metrics total_reservations --group-by metric_time__week

# Active members (single number)
mf query --metrics active_members

# Ideal weather hours by month
mf query --metrics ideal_weather_hours --group-by metric_time__month
```

---

## Connecting Google Sheets

### Prerequisites

- dbt Cloud Team or Enterprise plan with Semantic Layer enabled
- A successful production job run (MetricFlow needs a compiled semantic manifest)
- Google account with access to Google Sheets
- The **dbt Semantic Layer** add-on installed from Google Workspace Marketplace

### Step 1 — Enable the Semantic Layer in dbt Cloud

1. Go to **Account Settings → Projects → [your project]**
2. Click **Semantic Layer** in the left menu
3. Click **Enable Semantic Layer**
4. Note the **Environment ID** and **JDBC URL** — you will need these in Google Sheets

### Step 2 — Create a service token

1. Go to **Account Settings → Service Tokens → New Token**
2. Set permission to **Semantic Layer Only**
3. Copy the token value immediately — it is shown only once

### Step 3 — Install the Google Sheets add-on

1. In any Google Sheet, go to **Extensions → Add-ons → Get add-ons**
2. Search for **dbt Semantic Layer**
3. Install it and grant the requested permissions

### Step 4 — Configure the connection

1. Go to **Extensions → dbt Semantic Layer → Open**
2. In the sidebar, paste the **JDBC URL** and **Environment ID** from dbt Cloud
3. Paste the **service token**
4. Click **Connect** — the sidebar will populate with the list of available metrics

### Step 5 — Query metrics

Select a metric, choose dimensions to group by, apply any filters, and click **Query**. Results populate into the sheet starting at the selected cell.

| Query | Metric | Group By | What it shows |
| --- | --- | --- | --- |
| Monthly utilization | `court_utilization_rate` | `metric_time__month` | Seasonal demand patterns |
| Utilization per court | `court_utilization_rate` | `court_number` | Which courts are busiest |
| Bookings per week | `total_reservations` | `metric_time__week` | Weekly demand |
| Bookings by type | `total_reservations` | `reservation_type` | Membership vs. guest vs. events |
| Weather quality | `ideal_weather_hours` | `metric_time__month` | Utrecht tennis season |
| Members by gender | `active_members` | `gender` | Membership demographics |
| Members by type | `active_members` | `current_type_of_membership` | Membership mix |
