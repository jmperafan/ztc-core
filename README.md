# ZTC Court Usage — Demo Playground

This project uses real court reservation, member, and weather data from Zuilense Tennis Club (Utrecht, NL) as a realistic dbt dataset for client demos.

Each demo is implemented in the project and documented in [`docs/`](docs/). When a client asks about a feature, we build it here, then walk them through it using this codebase as a reference.

## Local setup

### 1. Install dependencies

```bash
pip install -r requirements-dev.txt
```

### 2. Configure credentials

Copy into a `.env` file (never commit it):

```bash
export SNOWFLAKE_ACCOUNT=fka50167
export SNOWFLAKE_USER=<your_username>
export SNOWFLAKE_PASSWORD=<your_password>
export SNOWFLAKE_ROLE=TRANSFORMER
export SNOWFLAKE_DATABASE=ANALYTICS_DEV
export SNOWFLAKE_WAREHOUSE=TRANSFORMING
```

Then load:

```bash
source .env
```

### 3. Install pre-commit hooks

```bash
pre-commit install
```

### 4. Run dbt

```bash
dbt debug                          # verify connection
dbt build                          # run all models + tests
dbt build --select staging         # staging layer only
dbt build --select +dim_members    # dim_members and all upstream
```

### 5. Scaffold YAML from the warehouse (optional)

[dbt-coves](https://github.com/datacoves/dbt-coves) introspects Snowflake and generates source/model YAML scaffolding. Run it when onboarding new tables — not on every commit. Connection details come from the active dbt profile, so make sure your `.env` is loaded first.

dbt-coves only supports Python `>=3.9,<3.13`, so install it in an isolated env via [pipx](https://pipx.pypa.io) rather than the main project:

```bash
brew install pipx python@3.12        # one-time prereqs
pipx install dbt-coves --python python3.12
```

Then:

```bash
dbt-coves generate sources       # scaffold source YAML for new tables
dbt-coves generate properties    # scaffold model property YAML
```

Static checks on existing YAML (descriptions, tests, freshness, etc.) are handled by the [dbt-checkpoint](https://github.com/dbt-checkpoint/dbt-checkpoint) pre-commit hooks configured in `.pre-commit-config.yaml`. Those run automatically on commit and require an up-to-date `target/manifest.json` — re-run `dbt parse` if the hooks complain about stale state.
