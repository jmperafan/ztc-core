# Macros

## The problem

Business logic leaks into SQL. The same calculation — age grouping, weather classification, text cleaning — is written once in staging, copied into a core model, and then written slightly differently in a mart. When the definition changes, three places need updating. One of them gets missed.

| Issue | Example |
| --- | --- |
| **Copy-paste logic** | The tennis weather condition (`temp BETWEEN 10 AND 35 AND precip = 0`) is defined in multiple models |
| **Inconsistent implementations** | Two analysts define "ideal weather" differently because neither knew the other had already built it |
| **Hardcoded SQL fragments** | A CASE statement for age groups appears in dim_members and again in an ad-hoc analysis |
| **No reuse across projects** | Useful logic is trapped inside one model instead of being shareable across the project |

Macros solve this by extracting reusable SQL fragments into named, parameterised functions that live in the `macros/` directory.

---

## How macros work

A macro is a Jinja function that returns a SQL string. It is defined with `{% macro %}` and called with `{{ }}`:

```sql
-- macros/my_macro.sql
{% macro my_macro(param) %}
    LOWER(TRIM({{ param }}))
{% endmacro %}

-- Usage in a model
SELECT {{ my_macro('event_description') }} AS clean_description
```

dbt discovers all macros in `macros/` automatically. No import or registration is needed.

---

## Macros in this project

This project has five macros, each encapsulating a specific business rule.

---

### `age_group(age)`

**File:** `macros/age_groups.sql`

Groups a continuous age value into 10-year buckets.

```sql
{% macro age_group(age) %}
    FLOOR({{ age }} / 10) * 10
{% endmacro %}
```

**Usage:**

```sql
-- models/core/dim_members.sql
{{ age_group('age') }} AS age_group
```

**Why it exists:** Age grouping is used for both member analytics and anonymous reporting. The calculation is simple but the semantics matter — a member who is 39 should fall in the `30` bucket, not the `40` bucket. Centralising this prevents the two common alternatives: rounding up (wrong) and hardcoding CASE ranges (brittle).

---

### `tennis_weather(temperature, precipitation, wind_speed)`

**File:** `macros/tennis_weather.sql`

Returns a boolean condition for ideal outdoor tennis conditions.

```sql
{% macro tennis_weather(temperature, precipitation, wind_speed) %}
    temperature BETWEEN 10 AND 35
    AND precipitation = 0
    AND wind_speed <= 20
{% endmacro %}
```

**Usage:**

```sql
-- models/core/fct_weather.sql
{{ tennis_weather("temperature", "precipitation", "wind_speed") }} AS ideal_weather
```

**Why it exists:** This is a business rule — what ZTC considers suitable conditions for outdoor court usage. Encoding it as a macro makes it the single source of truth. If the thresholds change (e.g., wind tolerance increases to 25 km/h), one file changes and every downstream model and metric picks it up.

---

### `clean_text(column)`

**File:** `macros/clean_text.sql`

Standardises a text column: lowercase, trim leading/trailing whitespace, collapse internal whitespace.

```sql
{% macro clean_text(column) %}
    REGEXP_REPLACE(
        LOWER(
            TRIM({{ column }})
        ),
        '\s+',
        ' '
    )
{% endmacro %}
```

**Usage:**

```sql
-- example: models/staging/stg_club_members.sql
{{ clean_text('woonplaats') }} AS city
```

**Why it exists:** Raw text data from member registrations is inconsistent — `'Utrecht'`, `' utrecht '`, and `'UTRECHT  '` all represent the same city. Centralising this logic in a macro means any staging model that needs clean text calls the same function rather than reimplementing it inline.

---

### `time_to_24_h(column)`

**File:** `macros/time_to_24_h.sql`

Converts a 12-hour time string (`'2:00:00 pm'`) to 24-hour format (`'14:00:00'`).

```sql
{% macro time_to_24_h(column) %}
CASE
    WHEN CONTAINS({{ column }}, 'am')
    OR (CONTAINS({{ column }}, 'pm') AND LEFT({{ column }}, 3) = '12:')
        THEN REGEXP_SUBSTR({{ column }}, '\\d{1,2}:\\d{2}:\\d{2}')

    WHEN CONTAINS({{ column }}, 'pm')
        THEN CONCAT(
            CAST(CAST(REGEXP_SUBSTR({{ column }}, '^\\d{1,2}') AS INTEGER) + 12 AS STRING),
            REGEXP_SUBSTR({{ column }}, ':\\d{2}:\\d{2}')
        )
END
{% endmacro %}
```

**Usage:**

```sql
-- example: any staging model receiving 12-hour time strings
{{ time_to_24_h('begintijd') }} AS start_time
```

**Why it exists:** Some source systems export times in 12-hour format. The rest of the project uses 24-hour timestamps. This macro handles the conversion — including the 12:xx am/pm edge case — in one place instead of each staging model that touches time columns.

---

### `is_winter_break(date)`

**File:** `macros/winter_break.sql`

Returns a boolean condition identifying whether a date falls within a known winter break period.

```sql
{% macro is_winter_break(date) %}
(
    -- Winter break in 2022
    {{ date }} >= '2022-01-01'
    AND {{ date }} <= '2022-03-19'
) OR (
    -- Winter break in 2023
    {{ date }} >= '2022-12-06'
    AND {{ date }} <= '2023-03-26'
)
{% endmacro %}
```

**Usage:**

```sql
-- models/core/fct_court_usage.sql
{{ is_winter_break('reservation_date') }} AS is_winter_break
```

**Why it exists:** Courts are closed during winter breaks, creating large gaps in court usage data. Naively calculating utilisation over these periods would severely understate demand. The `is_winter_break` flag lets downstream models and metrics exclude these periods. The exact date ranges are documented in the macro itself, making them easy to update when new seasons are added.

---

## Writing a new macro

```sql
-- macros/my_new_macro.sql
{% macro my_new_macro(param_1, param_2='default_value') %}
    -- SQL fragment using the parameters
    {{ param_1 }} = {{ param_2 }}
{% endmacro %}
```

Parameters can have default values. Call the macro by name in any model:

```sql
SELECT {{ my_new_macro('column_name') }} AS result
```

---

## Macros vs models

Macros and models solve different problems. A macro generates a SQL **fragment** (an expression, a condition, a clause). A model generates a SQL **statement** (a full SELECT that materialises as a table or view).

Use a macro when:
- The same SQL expression is needed in multiple models
- The logic involves a business rule that should have a single definition
- The expression is parameterised (the same pattern, different column names)

Use a model when:
- The output is a dataset that other models or analysts will query
- The logic involves joins, aggregations, or complex transformations
- The result needs to be materialised, tested, or documented

---

## Trade-offs

| Consideration | Detail |
| --- | --- |
| **Discoverability** | Macros are not visible in the dbt DAG. A developer reading a model needs to know to look in `macros/` to understand what `{{ tennis_weather(...) }}` does. |
| **Testing** | Macros themselves cannot be unit tested directly in dbt. Their correctness is verified indirectly through tests on models that use them. |
| **Debugging** | A macro error surfaces as a compile error. Use `dbt compile --select <model>` and inspect `target/compiled/` to see the expanded SQL. |
| **Overuse** | A macro that is only used once is not obviously better than inline SQL. The benefit of a macro is the reuse and the single source of truth, not the abstraction itself. |
