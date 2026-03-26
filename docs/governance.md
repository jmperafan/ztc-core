# dbt Model Governance

dbt Model Governance is a set of three features — **groups**, **access**, and **contracts** — that make the ownership and stability guarantees of a dbt project explicit and enforced.

Without them, the project relies on conventions people follow voluntarily: staging models _should_ only be referenced internally, core models _should_ have stable schemas. Model Governance turns those conventions into constraints that dbt enforces at parse or build time.

---

## The three features

### Groups

A group is a named owner for a set of models. It identifies who is responsible for a model — not just for documentation purposes, but as the enforcement boundary for access rules.

Groups are defined in a `.yml` file with a `groups:` key:

```yaml
# models/_groups.yml
groups:
  - name: analytics_engineering
    owner:
      name: Analytics Engineering
      email: analytics@ztc-utrecht.nl

  - name: data_science
    owner:
      name: Data Science
      email: datascience@ztc-utrecht.nl
```

A model is assigned to a group with the `group:` property:

```yaml
models:
  - name: stg_reservations
    group: analytics_engineering
```

On its own, a group is just metadata. It becomes meaningful when combined with access.

---

### Access

Access controls which models can reference a model from outside its group. There are three levels:

| Level | Who can reference it |
| --- | --- |
| `private` | Only models in the same group |
| `protected` | Any model in the same project (default) |
| `public` | Any model in any project |

```yaml
models:
  - name: stg_reservations
    group: analytics_engineering
    access: private   # only models in analytics_engineering can ref this

  - name: fct_court_usage
    group: analytics_engineering
    access: public    # any model anywhere can ref this
```

If a model outside `analytics_engineering` tries to `{{ ref('stg_reservations') }}`, dbt will raise a parse error:

```text
Model "data_science.python_court_stats" attempted to reference
"analytics_engineering.stg_reservations", which is private.
```

This is the access constraint working. `stg_reservations` is internal plumbing — it exists to feed `int_` and `core` models, not to be queried directly from marts or external projects.

**Why this matters**: Without access enforcement, nothing prevents a mart from referencing a staging model directly. That bypasses the entire intermediate and core layer, breaks the medallion architecture, and creates a hidden dependency that is invisible to code review.

---

### Contracts

A contract declares the expected schema of a model: the column names, their data types, and optionally constraints. When a contract is enforced, dbt verifies at build time that the model's actual output matches the declared schema.

```yaml
models:
  - name: fct_court_usage
    config:
      contract:
        enforced: true
    columns:
      - name: slot_key
        data_type: varchar
      - name: court_number
        data_type: number
      - name: reservation_date
        data_type: date
      - name: is_winter_break
        data_type: boolean
      # ... all columns must be listed
```

If the model produces a column that is not listed, or produces a column with the wrong type, the build fails before the table is written.

**Why this matters**: `fct_court_usage` is a `public` model. It feeds the semantic layer, downstream mart models, and dashboards. If a developer renames `duration_in_mins` to `duration_minutes` or changes a `boolean` column to `varchar`, every downstream consumer breaks silently — unless a contract catches it first.

A contract is a commitment: this model's interface is stable. If you break it, dbt tells you immediately.

---

## How they work together

The three features form a layered ownership model:

```text
groups define who owns what
    │
    ▼
access defines who can see what
    │
    ▼
contracts define what the interface looks like
```

In practice, the architecture maps to access levels like this:

| Layer | Group | Access | Rationale |
| --- | --- | --- | --- |
| `staging/` | `analytics_engineering` | `private` | Internal plumbing — only the AE team's models should ref these |
| `intermediate/` | `analytics_engineering` | `private` | Same — internal implementation details |
| `core/` | `analytics_engineering` | `public` | Stable, tested API — anyone can build on these |
| `marts/sql` | `analytics_engineering` | `public` | Consumer-facing outputs |
| `marts/python` | `data_science` | `public` | Data science outputs |

---

## What is implemented in this project

### Groups (`models/_groups.yml`)

Two groups are declared:

```yaml
groups:
  - name: analytics_engineering
    owner:
      email: analytics@ztc-utrecht.nl

  - name: data_science
    owner:
      email: datascience@ztc-utrecht.nl
```

### Contracts (`models/core/_models.yml`)

`fct_court_usage` has a contract enforced. All 10 columns are declared with explicit Snowflake data types:

```yaml
- name: fct_court_usage
  config:
    contract:
      enforced: true
  columns:
    - name: slot_key
      data_type: varchar
    - name: reservation_id
      data_type: varchar
    - name: court_number
      data_type: number
    - name: reservation_date
      data_type: date
    - name: start_time
      data_type: time
    - name: end_time
      data_type: time
    - name: reservation_type
      data_type: varchar
    - name: event_description
      data_type: varchar
    - name: duration_in_mins
      data_type: number
    - name: is_winter_break
      data_type: boolean
```

This is the right model to start with: it is `public`, feeds the semantic layer, and has a fixed grain (court × slot) that should not change without a deliberate decision.

### Access and group assignment

`group:` and `access:` are standard dbt model properties (top-level in `_models.yml`, alongside `description:` and `columns:`). They are supported by dbt-core 1.5+ and by dbt Cloud's standard runtime.

This project runs **dbt-fusion 2.0.0-preview**, which is Snowflake's new Rust-based dbt runtime. As of preview.161, dbt-fusion does not yet recognize `group:` and `access:` as valid model properties — they are parsed as unknown keys and ignored. The property syntax is correct; the runtime support is pending.

When dbt-fusion adds support, the configuration to add is:

```yaml
# staging/_models.yml
- name: stg_reservations
  group: analytics_engineering
  access: private

# intermediate/_models.yml
- name: int_court_usage
  group: analytics_engineering
  access: private

# core/_models.yml
- name: fct_court_usage
  group: analytics_engineering
  access: public

# marts/_models.yml
- name: python_demand_forecast
  group: data_science
  access: public
```

---

## Extending contracts to other models

`fct_court_usage` is a good starting point, but contracts are most valuable on all `public` models. The steps to add a contract to any model:

1. Add `config: contract: enforced: true` to the model in its `_models.yml`
2. Add `data_type:` to every column listed
3. Run `dbt build -s <model_name>` — dbt will report any type mismatches before the table is written

For models that use `SELECT *` (like `dim_members`), the contract requires listing every column that `*` expands to. The easiest way to discover the full column list is `dbt show -s dim_members` or reading the upstream model's column definitions.

---

## Further reading

- [dbt docs: Model access](https://docs.getdbt.com/docs/collaborate/govern/model-access)
- [dbt docs: Model contracts](https://docs.getdbt.com/docs/collaborate/govern/model-contracts)
- [dbt docs: Model versions](https://docs.getdbt.com/docs/collaborate/govern/model-versions)
