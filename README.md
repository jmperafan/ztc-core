# ZTC Court Usage — Demo Playground

This project uses real court reservation, member, and weather data from Zuilense Tennis Club (Utrecht, NL) as a realistic dbt dataset for client demos.

Each demo is implemented in the project and documented in [`docs/`](docs/). When a client asks about a feature, we build it here, then walk them through it using this codebase as a reference.

---

## Demos

| Topic | Doc |
| --- | --- |
| CI/CD (pre-commit, SQLFluff, dbt Bouncer, GitHub Actions, dbt Cloud) | [docs/ci.md](docs/ci.md) |
| Semantic Layer (MetricFlow, metrics as code, Google Sheets connector) | [docs/semantic_layer.md](docs/semantic_layer.md) |

---

## Project structure

```text
models/
├── staging/        # Rename & cast raw Snowflake columns (views)
├── intermediate/   # Business logic & gap-filling (views)
├── core/           # Fact & dimension tables (tables)
└── marts/          # Anonymised analytical outputs (tables)
docs/               # One markdown file per demo topic
scripts/            # Utility scripts (e.g. data upload)
```

Source data lives in `RAW.ZTC` (Snowflake). Transformed models land in `ANALYTICS_DEV.<schema>`.

---

## Adding a new demo

1. Implement the feature in the project
2. Create `docs/<topic>.md` explaining the concept, the options, and how this project demonstrates it
3. Add a row to the Demos table above

---

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
