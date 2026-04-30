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

### 5. Sync YAML documentation (optional)

dbt-osmosis keeps YAML schema files accurate and propagates column descriptions across the lineage. Run it after building models to catch any drift:

```bash
dbt-osmosis yaml refactor --check  # check only, no writes
dbt-osmosis yaml refactor          # apply fixes in place
```

See [`docs/dbt-osmosis.md`](docs/dbt-osmosis.md) for details.
