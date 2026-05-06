# Jinja in dbt

## The problem

SQL is not a programming language. It has no variables, no loops, no conditionals, and no reusable functions. In a real project, this leads to predictable problems:

| Issue | Example |
| --- | --- |
| **Hardcoded values** | The same date range (`'2022-01-01'` to `'2025-01-01'`) is written in 8 different models |
| **Repetitive SQL** | The same UNION pattern for 5 courts is copy-pasted 5 times |
| **No abstraction** | Changing a business rule means finding and updating every model that encodes it |
| **Environment drift** | Dev and prod reference different database names with no systematic way to manage this |

dbt solves this by compiling Jinja templates into SQL at runtime. Every `.sql` file in a dbt project is a Jinja template first, SQL second.

---

## How Jinja works in dbt

Jinja uses two types of delimiters:

| Delimiter | Purpose | Example |
| --- | --- | --- |
| `{{ ... }}` | Expressions — outputs a value | `{{ ref('dim_members') }}` |
| `{% ... %}` | Statements — controls flow, no output | `{% for i in [1,2,3] %}` |
| `{# ... #}` | Comments — stripped at compile time | `{# TODO: fix this #}` |

When you run `dbt compile`, every Jinja expression is evaluated and replaced with its SQL equivalent. What dbt sends to the warehouse is plain SQL.

---

## Expressions: `{{ }}`

### `ref()` and `source()`

The two most important functions in dbt are both Jinja expressions.

```sql
-- ref() builds a dependency on another model
SELECT * FROM {{ ref('dim_members') }}

-- source() builds a dependency on a raw source table
SELECT * FROM {{ source('ztc', 'court_usage') }}
```

Both resolve to the fully-qualified table name for the current environment and register the dependency in the DAG. This is what makes `dbt run --select +dim_members` work — dbt knows the graph because every `ref()` and `source()` call is explicit.

### Variables

Project variables are defined in `dbt_project.yml` and accessed with `var()`:

```yaml
# dbt_project.yml
vars:
  start_date: '2022-01-01'
  opening_time: '08:00:00'
  closing_time: '23:00:00'
  court_numbers: [1, 2, 3, 4, 5]
```

```sql
-- models/core/dim_calendar.sql
WHERE date_key >= '{{ var("start_date") }}'
  AND date_key < CURRENT_DATE()
```

Change `start_date` in one place, and every model that uses `var("start_date")` picks it up. Variables can also be overridden at runtime:

```bash
dbt run --vars '{"start_date": "2023-01-01"}'
```

---

## Statements: `{% %}`

### For loops

Use loops to generate repetitive SQL without copy-paste. This project uses a loop to build the court-date spine across all 5 courts:

```sql
-- models/intermediate/int_court_date_spine.sql
{%- for court_number in var('court_numbers') -%}
    SELECT
        {{ court_number }} AS court_number,
        date_key AS reservation_date
    FROM dim_calendar
    {%- if not loop.last %} UNION DISTINCT {% endif -%}
{% endfor %}
```

This compiles to:

```sql
SELECT 1 AS court_number, date_key AS reservation_date FROM dim_calendar
UNION DISTINCT
SELECT 2 AS court_number, date_key AS reservation_date FROM dim_calendar
UNION DISTINCT
-- ... and so on for courts 3, 4, 5
```

Adding a 6th court means updating `court_numbers` in `dbt_project.yml` from `[1, 2, 3, 4, 5]` to `[1, 2, 3, 4, 5, 6]` in one place.

The `loop` object provides useful properties inside a for loop:

| Property | Value |
| --- | --- |
| `loop.index` | Current iteration (1-based) |
| `loop.index0` | Current iteration (0-based) |
| `loop.first` | `true` on the first iteration |
| `loop.last` | `true` on the last iteration |

### Conditionals

Use `if`/`elif`/`else` to branch logic. A common pattern is environment-aware config:

```sql
{% if target.name == 'prod' %}
    SELECT * FROM full_table
{% else %}
    SELECT * FROM full_table WHERE reservation_date >= DATEADD('day', -90, CURRENT_DATE)
{% endif %}
```

Or conditional column inclusion:

```sql
SELECT
    reservation_id,
    reservation_date,
    {% if var('include_member_data', false) %}
        member_id,
        player_1,
    {% endif %}
    court_number
FROM reservations
```

### Set

Use `{% set %}` to assign a value to a variable within a template:

```sql
{% set courts = [1, 2, 3, 4, 5] %}
{% set current_season = 'summer' %}

SELECT
    {% for court in courts %}
        SUM(CASE WHEN court_number = {{ court }} THEN duration_minutes ELSE 0 END) AS court_{{ court }}_minutes
        {% if not loop.last %},{% endif %}
    {% endfor %}
FROM fct_reservations
```

---

## The `target` object

dbt exposes a `target` object with information about the current execution environment:

| Property | Example value |
| --- | --- |
| `target.name` | `'dev'`, `'prod'`, `'ci'` |
| `target.schema` | `'dbt_jperafan'` |
| `target.database` | `'ANALYTICS'` |
| `target.type` | `'snowflake'`, `'bigquery'` |

This is used to write environment-aware models — limiting data in dev, using full scans in prod.

---

## `config()` blocks

Every model can have a `config()` block that sets materialisation, tags, and other properties:

```sql
{{ config(
    materialized='incremental',
    unique_key='reservation_id',
    tags=['core', 'daily']
) }}

SELECT * FROM {{ ref('stg_reservations') }}
```

Config blocks are Jinja expressions. They are evaluated before the SQL is compiled, which is why they can reference `var()` and `target` but not other models.

---

## Compile vs run

To see what Jinja resolves to without executing anything:

```bash
# Compile a single model and write to target/compiled/
dbt compile --select int_court_date_spine

# Print compiled SQL directly to the terminal (dbt 1.5+)
dbt compile --select int_court_date_spine --output text
```

The compiled output lives in `target/compiled/ztc_core/models/`. Inspecting it is useful when debugging unexpected query shapes.

---

## Trade-offs

| Consideration | Detail |
| --- | --- |
| **Readability** | Heavy Jinja makes SQL harder to read at a glance. Prefer simple, readable Jinja over clever one-liners. |
| **Debugging** | Errors in Jinja templates surface as compile errors, not SQL errors. `dbt compile` is your first debug step. |
| **Overuse** | Not every repetitive SQL needs Jinja. If a loop generates SQL that could be a simple GROUP BY, use the GROUP BY. |
| **Editor support** | Most SQL editors don't syntax-highlight Jinja. dbt Power User for VS Code is the exception. |
