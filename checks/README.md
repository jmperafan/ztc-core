# Project quality checks

SQL assertions about this project's *metadata*, not its data. They run in an
embedded DuckDB against the dbt Information Schema, need no warehouse
connection, and finish in about a second for the whole suite. A check passes
when its query returns zero rows.

```bash
dbt check                      # all of them
dbt check naming_conventions   # one, by file stem
dbt build                      # runs them first, before any warehouse work
```

CI runs them in `.github/workflows/checks.yml`, which deliberately has no
credentials — see the header of that file.

## Layout

One rule-group per file, in theme directories. `checks/` recurses and a
check's name is its bare file stem regardless of depth, so
`checks/access/grants_policy.sql` is just `grants_policy`.

| Directory | Covers |
|---|---|
| `access/` | public/private boundaries, grants, group ownership |
| `contracts/` | contract types, primary keys, snapshot config |
| `documentation/` | description floors, column descriptions |
| `naming/` | prefixes, file names, directory layout, property-file location |
| `lineage/` | layering invariants, materialization policy |
| `thresholds/` | tunable ceilings (fanout, upstream count) |
| `sources/` `exposures/` `metadata/` `macros/` `testing/` | as named |

**Do not consolidate these into fewer, larger scripts.** `severity`, `enabled`
and `selection_filter_on` are properties of a check *file*, and the file stem
is the only selection handle there is (`dbt check --select tag:x` matches
resources, not checks, and runs nothing). Merging rules would permanently
forfeit the ability to run, disable or warn-tier any of them individually.
Runtime is not a reason to merge: the checks sum to ~0.25s and the rest is
process startup.

## History: this replaced dbt-bouncer

dbt-bouncer used to run ~1,700 assertions here. Its rules were migrated into
this directory in September 2026 and the tool was removed. Each check file
names the bouncer rules it replaces in its header comment.

### Rules that could not be migrated, and are now unenforced

The check view is a narrow subset of the Information Schema — 27 columns on
models, 6 on `node_columns`. It has no `raw_code`, so model SQL text is
invisible to it. These lost their enforcement when bouncer was removed:

| Former bouncer rule | Status |
|---|---|
| `check_model_hard_coded_references` | **covered** — dbt-checkpoint `check-script-ref-and-source` in pre-commit |
| `check_model_has_semi_colon` | **covered** — local pre-commit hook |
| `check_model_max_number_of_lines` | **covered** — local pre-commit hook |
| `check_model_code_does_not_contain_regexp_pattern` | **covered** — local pre-commit hook |
| `check_source_pii_meta` | **LOST** — `node_columns` exposes `tags`, not `meta`, and PII is labelled here as column `config.meta.pii` |
| `check_macro_arguments_description_populated` | **LOST** — `macros.arguments` carries `name` and `is_optional` but no per-argument description |
| `check_model_max_chained_views` | **LOST** — a port was attempted and abandoned; see below |
| `check_project_name` | dropped as low value; the name is fixed in `dbt_project.yml` |
| `check_seed_*`, `check_semantic_model_*` | dormant — no seeds or semantic models exist |

To recover the PII rule, relabel those source columns with `tags: [pii]` (or
the v2 `classifiers` config once the check view exposes it) and add a check
over `node_columns.tags`.

On `check_model_max_chained_views`: bouncer counts with
`materializations_to_include: [ephemeral, view]` and a threshold of 3,
reporting 4 models. A recursive CTE walking upward through non-table parents
reproduces only 2 of them, and one that walks all ancestors reports 20. The
exact semantics were not pinned down, so no check was shipped rather than one
that claims parity and quietly differs.

## Considered and rejected

Preserved verbatim from dbt-bouncer's Tier 3 block. Each entry was evaluated
against the real manifest and rejected for cause — check here before adding a
rule that looks like an obvious win.

**`check_model_incremental_has_unique_key`** — does not understand the
microbatch strategy. `fct_reservation_events` is microbatch, which achieves
idempotency by replacing whole batches selected by `event_time`; `unique_key`
is unused and dbt ignores it. The rule only tests
`materialized == 'incremental'`, so it reports a false positive.

**`check_column_descriptions_are_consistent`** — requires one canonical
description per column *name* project-wide. `status` legitimately means
invoice status in `fct_invoices` and lesson status in `fct_lessons`;
`category` differs per entity. It also treats a deliberate caveat ("NULL for
orphaned members") as a conflict. ~60 column names flagged, the large majority
correctly documented. The real fix for genuine drift ("°C" vs "degrees
Celsius") is doc blocks.

**`check_macro_is_used`** — cannot see `dbt run-operation` or downstream
cross-project usage, so it flags macros that are used-but-not-by-a-model.
`check_target` is a diagnostic invoked via run-operation, and
`precipitation_alert_threshold` demonstrates the `env_var()` pattern.

**`check_model_does_not_use_select_star`** — fires on the idiomatic import CTE
(`SELECT * FROM {{ ref(...) }}`) and `SELECT * FROM final`, which this project
uses everywhere.

**`check_model_has_constraints`** — reads only model-level `constraints:`.
This project declares primary keys at column level (with
`warn_unenforced: false`, which is what silences dbt1109 on Snowflake).
Declaring both forms emits two PRIMARY KEY clauses and breaks CREATE TABLE.
`contracts/core_models_declare_a_primary_key.sql` is what verifies them.
