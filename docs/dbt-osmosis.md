# dbt-osmosis — Column-level Documentation Automation

## The problem

dbt makes it easy to document models in YAML, but keeping that documentation accurate is a manual, error-prone process. In practice, three things go wrong:

| Issue | What happens |
| --- | --- |
| **Columns fall out of sync** | A developer adds or renames a column in SQL but forgets to update the YAML. The documentation is now wrong. |
| **Descriptions aren't reused** | `customer_id` is described in `stg_reservations.yml`. The same column appears in `fct_reservations` and `dim_members`, but those descriptions are blank — or worse, inconsistent. |
| **YAML files end up in the wrong place** | A model moves from one subfolder to another. Its YAML block is still in the old file. |

dbt-osmosis solves all three automatically.

---

## How it works

dbt-osmosis has two commands that cover different parts of the problem.

### `yaml organize`

Reads the dbt project structure and checks that every model's YAML documentation block is in the file where osmosis expects it to be (based on `+dbt-osmosis` routing in `dbt_project.yml`). If a model is documented in the wrong file, it flags it.

### `yaml refactor`

Does everything `yaml organize` does, plus:

1. **Queries the warehouse** to discover the actual columns on each model.
2. **Adds missing columns** to the YAML that exist in the database but aren't documented yet.
3. **Removes stale columns** from the YAML that no longer exist in the database.
4. **Propagates descriptions** — if a column in a downstream model has an empty description, and the same column appears in an upstream model with a description, osmosis copies the description downstream automatically.

### Key flags

| Flag | Meaning |
| --- | --- |
| `-C` / `--check` | Exit with a non-zero code if any files would change. Does not write to disk. |
| `--dry-run` | Show a diff of what would change without writing. Combine with `-C` to both preview and fail fast. |
| `--disable-introspection` | Skip warehouse column queries. Useful when no DB credentials are available (e.g. pre-commit). |
| `--auto-apply` | Apply all changes without an interactive confirmation prompt. |

---

## Routing config — why it's not in dbt_project.yml

osmosis normally reads a `+dbt-osmosis` key from `dbt_project.yml` to know which YAML file to route each model's documentation into. This project uses dbt Fusion, which performs strict schema validation and rejects unknown `+` keys — so that approach is off the table.

Instead, osmosis supports a fallback: a `dbt_osmosis_default_path` dbt variable, which can be passed directly on the command line without touching any project file:

```bash
dbt-osmosis yaml refactor -C --vars '{"dbt_osmosis_default_path": "_{model}.yml"}'
```

The CI workflow uses this flag. `dbt_project.yml` stays Fusion-clean, and the routing config is ephemeral to the runner.

---

## Where each command runs

| | Pre-commit | GitHub Actions CI |
| --- | --- | --- |
| Command | `yaml refactor --disable-introspection -C` | `yaml refactor -C` |
| DB credentials needed | No | Yes |
| Catches YAML file misplacement | ✅ | ✅ |
| Catches doc propagation gaps | ✅ | ✅ |
| Catches missing/stale columns from DB | ❌ | ✅ |

Pre-commit uses `--disable-introspection` so it works without Snowflake credentials. CI has full credentials and catches everything including column drift.

---

## Pre-commit setup

The hook is already configured in `.pre-commit-config.yaml`. It uses the upstream dbt-osmosis repo directly and runs `yaml refactor --disable-introspection -C` on every commit that touches a `.sql` or `.yml` file.

**Install hooks** (one-time, per clone):

```bash
pre-commit install
```

**Run manually against all files:**

```bash
pre-commit run dbt-osmosis --all-files
```

If the hook fails, it means at least one YAML file is misplaced or a description could be propagated from an upstream model but isn't. Fix locally:

```bash
dbt-osmosis yaml refactor --disable-introspection
```

Then re-stage and commit.

---

## CI setup

The GitHub Actions workflow at `.github/workflows/04-osmosis.yml` runs `yaml refactor -C` against a live Snowflake connection on every pull request to `main`. It requires the following repository secrets:

| Secret | Value |
| --- | --- |
| `SNOWFLAKE_ACCOUNT` | e.g. `fka50167` |
| `SNOWFLAKE_USER` | your Snowflake username |
| `SNOWFLAKE_PASSWORD` | your Snowflake password |
| `SNOWFLAKE_ROLE` | e.g. `TRANSFORMER` |
| `SNOWFLAKE_DATABASE` | e.g. `ANALYTICS_DEV` |
| `SNOWFLAKE_WAREHOUSE` | e.g. `TRANSFORMING` |

If the workflow fails, it means at least one YAML file has columns that don't match the database, or descriptions that could be propagated but aren't.

---

## Running locally

Source your credentials first:

```bash
source .env
```

**Check without writing (preview mode):**

```bash
dbt-osmosis yaml refactor --dry-run -C --vars '{"dbt_osmosis_default_path": "_{model}.yml"}'
```

**Check without DB credentials:**

```bash
dbt-osmosis yaml refactor --disable-introspection -C --vars '{"dbt_osmosis_default_path": "_{model}.yml"}'
```

**Apply fixes in place:**

```bash
dbt-osmosis yaml refactor --auto-apply --vars '{"dbt_osmosis_default_path": "_{model}.yml"}'
```

After applying fixes, review the diff before committing. osmosis may have:
- Added columns that exist in the database but were missing from YAML
- Removed columns that no longer exist in the database
- Filled in empty descriptions by propagating them from upstream models

---

## How description propagation works

Given this lineage:

```
stg_reservations  ──►  int_court_usage  ──►  fct_court_usage
```

If `staging/_{model}.yml` has:

```yaml
- name: court_id
  description: Unique identifier for the tennis court (1–5).
```

And `core/_{model}.yml` has:

```yaml
- name: court_id
  description: ""
```

After `dbt-osmosis yaml refactor`, the downstream description is automatically filled:

```yaml
- name: court_id
  description: Unique identifier for the tennis court (1–5).
```

The rule: osmosis only propagates if the downstream description is empty. It never overwrites a description you've written intentionally.

---

## Trade-offs

**What osmosis is good at**: keeping YAML accurate mechanically — column lists, file placement, description inheritance.

**What osmosis doesn't do**: write meaningful descriptions for you. If a column has no description anywhere in the lineage, osmosis leaves it blank. Someone still has to write the first description.

**The practical workflow**: when a developer adds a new model, they write descriptions only at the staging layer. osmosis propagates those descriptions downstream automatically. Core and mart models get documentation for free on any column that flows through unchanged from staging.
