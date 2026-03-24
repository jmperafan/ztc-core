# ZTC Court Usage

dbt project for analysing court reservations, member demographics, and weather data for Zuilense Tennis Club (Utrecht, NL).

---

## Project structure

```text
models/
├── staging/        # Rename & cast raw Snowflake columns (views)
├── intermediate/   # Business logic & gap-filling (views)
├── core/           # Fact & dimension tables (tables)
└── marts/          # Anonymised analytical outputs (tables)
```

Source data lives in `RAW.ZTC` (Snowflake). Transformed models are written to `ANALYTICS_DEV.<schema>`.

---

## Local setup

### 1. Install dependencies

```bash
pip install -r requirements-dev.txt
```

### 2. Configure credentials

Copy the env vars below into a `.env` file (never commit it):

```bash
export SNOWFLAKE_ACCOUNT=fka50167
export SNOWFLAKE_USER=<your_username>
export SNOWFLAKE_PASSWORD=<your_password>
export SNOWFLAKE_ROLE=TRANSFORMER
export SNOWFLAKE_DATABASE=ANALYTICS_DEV
export SNOWFLAKE_WAREHOUSE=TRANSFORMING
```

Then load them:

```bash
source .env
```

### 3. Run dbt

```bash
dbt debug          # verify connection
dbt build          # run all models + tests
dbt build --select staging         # run only staging layer
dbt build --select +dim_members    # run dim_members and all upstream models
```

---

## Pre-commit hooks

Hooks run automatically on every `git commit`:

- Trailing whitespace / end-of-file checks
- Prevents direct commits to `main`
- SQLFluff lint & auto-fix

Install once:

```bash
pre-commit install
```

Run manually against all files:

```bash
pre-commit run --all-files
```

---

## SQLFluff

Lints SQL files for style consistency (Snowflake dialect).

```bash
# Lint
sqlfluff lint models/ --dialect snowflake

# Auto-fix
sqlfluff fix models/ --dialect snowflake
```

Config lives in [.sqlfluff](.sqlfluff). Key rules enforced:

- Keywords, functions, and types must be UPPERCASE
- Max line length: 120

---

## dbt Bouncer

Enforces project conventions by inspecting the dbt manifest.

```bash
# Generate manifest first
dbt parse

# Run checks
dbt-bouncer --config dbt-bouncer.yml
```

Config lives in [dbt-bouncer.yml](dbt-bouncer.yml). Checks enforced:

- Staging models must be named `stg_*`
- Intermediate models must be named `int_*`
- Core models must be named `fct_*`, `dim_*`, or `bridge_*`
- Core models must have a unique test
- Staging models must have no upstream dbt dependencies (sources only)

---

## CI pipeline (GitHub Actions)

Three jobs run on every pull request to `main`:

| Job | What it does |
| --- | --- |
| **Lint** | pre-commit hooks + SQLFluff lint |
| **dbt Bouncer** | `dbt parse` → enforce naming & testing conventions |
| **dbt build (Slim CI)** | Build only modified models in an isolated PR schema |

### Required GitHub Secrets

Add these under **Settings → Secrets → Actions**:

| Secret | Value |
| --- | --- |
| `SNOWFLAKE_ACCOUNT` | `fka50167` |
| `SNOWFLAKE_USER` | your username |
| `SNOWFLAKE_PASSWORD` | your password |
| `SNOWFLAKE_ROLE` | `TRANSFORMER` |
| `SNOWFLAKE_DATABASE` | `ANALYTICS_DEV` |
| `SNOWFLAKE_WAREHOUSE` | `TRANSFORMING` |

---

## dbt Cloud CI

dbt Cloud runs Slim CI automatically on every PR:

1. **dbt Cloud → Deploy → Environments** — create a `CI` environment pointing at `ANALYTICS_DEV`
2. **Deploy → Jobs → Create job** — select "Continuous Integration Job"
3. Set command: `dbt build --select state:modified+ --defer --state ./target`
4. Link to the GitHub repo — dbt Cloud will post a status check on every PR
