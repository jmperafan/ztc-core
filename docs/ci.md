# CI/CD for dbt Projects

This document explains the CI/CD options available for dbt projects and shows how each one is implemented in this repo.

---

## What problem does CI solve?

Without CI, broken SQL ships to production. A developer changes a model, pushes to main, and the next morning the dashboard is empty. CI catches this before it merges by running checks and builds automatically on every pull request.

For dbt specifically, CI typically covers four concerns:

| Concern | Question it answers |
| --- | --- |
| **Code style** | Is the SQL formatted consistently? |
| **Project conventions** | Are models named correctly? Do they have tests and docs? |
| **Correctness** | Does the SQL actually run without errors? |
| **Impact** | Which downstream models are affected by this change? |

---

## The options

### 1. Pre-commit hooks

**What it is**: Checks that run locally before a `git commit` is allowed to complete. Catches issues before they ever reach the remote.

**Best for**: Fast feedback on the developer's machine. No CI credits consumed.

**Trade-off**: Only runs if the developer has installed the hooks (`pre-commit install`). Can be bypassed with `git commit --no-verify`.

**Configured in**: [`.pre-commit-config.yaml`](../.pre-commit-config.yaml)

This project runs:

- `trailing-whitespace` — removes trailing spaces
- `end-of-file-fixer` — ensures files end with a newline
- `check-yaml` — validates YAML syntax
- `no-commit-to-branch` — blocks direct commits to `main`
- `sqlfluff-lint` + `sqlfluff-fix` — lints and auto-fixes SQL style

**How to use**:

```bash
# Install once per machine
pre-commit install

# Run manually against everything
pre-commit run --all-files

# Skip hooks for a single commit (use sparingly)
git commit --no-verify
```

---

### 2. SQLFluff

**What it is**: A SQL linter and auto-formatter. Enforces consistent style — capitalisation, indentation, line length, and more.

**Best for**: Teams with mixed SQL backgrounds. Stops style debates in code review.

**Trade-off**: Can be noisy on legacy code. Configure rules incrementally.

**Configured in**: [`.sqlfluff`](../.sqlfluff)

This project enforces:

- Snowflake dialect
- Keywords, functions, and types in UPPERCASE
- Max line length of 120 characters

**How to use**:

```bash
# Check for violations
sqlfluff lint models/

# Auto-fix what can be fixed
sqlfluff fix models/

# Lint a single file
sqlfluff lint models/core/fct_reservations.sql
```

**Templater note**: We use the `jinja` templater (not `dbt`) so SQLFluff works without a live database connection. This is the right choice for CI environments.

---

### 3. dbt Bouncer

**What it is**: A tool that reads the dbt manifest and enforces project conventions as code. Think of it as a linter for your dbt project structure, not just your SQL.

**Best for**: Teams that want to enforce naming conventions, documentation requirements, and testing standards automatically — instead of relying on code review.

**Trade-off**: Requires `dbt parse` to generate a manifest first. Rules need to be tuned to your project's conventions.

**Configured in**: [`dbt-bouncer.yml`](../dbt-bouncer.yml)

This project enforces:

| Check | Rule |
| --- | --- |
| Naming — staging | Model names must match `^stg_` |
| Naming — intermediate | Model names must match `^int_` |
| Naming — core | Model names must match `^(fct_\|dim_\|bridge_)` |
| Naming — marts | Model names must match `^(fct_\|dim_)` |
| Testing | Core models must have a unique test |
| Structure | No model may have more than 10 downstream dependencies |
| Lineage | Staging models may only read from sources, not other models |

**How to use**:

```bash
# Generate the manifest (no database connection needed)
dbt parse

# Run bouncer checks
dbt-bouncer --config dbt-bouncer.yml
```

**In GitHub Actions**, dbt Bouncer posts a comment directly on the PR listing any violations, so reviewers see them without opening the Actions log.

---

### 4. GitHub Actions

**What it is**: Automated workflows that run on GitHub's infrastructure in response to events (pull requests, pushes, schedules).

**Best for**: Teams not on dbt Cloud, or teams that want additional checks beyond what dbt Cloud CI offers.

**Trade-off**: Requires managing Snowflake credentials as GitHub secrets. Each run spins up a fresh environment and installs all dependencies, so it's slower than dbt Cloud CI.

**Configured in**: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

This project runs three jobs on every PR to `main`:

```
lint ──► bouncer ──► dbt build (slim CI)
```

**Job 1 — lint** (no Snowflake connection needed):

- Runs pre-commit hooks
- Runs SQLFluff lint across `models/` and `macros/`

**Job 2 — bouncer** (requires Snowflake to run `dbt parse`):

- Writes a `profiles.yml` from GitHub Secrets
- Runs `dbt parse` to generate `target/manifest.json`
- Runs dbt Bouncer and posts results as a PR comment

**Job 3 — dbt build (Slim CI)**:

- Builds only modified models and their downstream dependencies
- Runs in an isolated schema `ci_pr_<number>` so it never touches dev or prod
- Uses `--defer --state ./target` to reference unmodified models from the last production run instead of rebuilding everything

**Required GitHub Secrets** — add under Settings → Secrets → Actions:

| Secret | Value |
| --- | --- |
| `SNOWFLAKE_ACCOUNT` | `fka50167` |
| `SNOWFLAKE_USER` | your username |
| `SNOWFLAKE_PASSWORD` | your password |
| `SNOWFLAKE_ROLE` | `TRANSFORMER` |
| `SNOWFLAKE_DATABASE` | `ANALYTICS_DEV` |
| `SNOWFLAKE_WAREHOUSE` | `TRANSFORMING` |

---

### 5. dbt Cloud CI

**What it is**: dbt Cloud's built-in CI feature. When a PR is opened, dbt Cloud automatically runs a dbt build and posts the result as a GitHub status check.

**Best for**: Teams already on dbt Cloud. Zero infrastructure to manage — no GitHub secrets, no self-hosted runners.

**Trade-off**: Requires a dbt Cloud account. The Slim CI `--defer` feature requires a successful production run to defer against.

**How to set it up**:

1. **Create a CI environment** — dbt Cloud → Deploy → Environments → New Environment → set type to "Staging/CI"
2. **Create a CI job** — Deploy → Jobs → Create Job → select "Continuous Integration Job"
3. **Set the command**: `dbt build --select state:modified+ --defer --state ./target`
4. **Connect the repo** — dbt Cloud posts a status check on every PR; the PR cannot merge until it passes

**Slim CI** means only the models touched in the PR (and their downstream dependents) are rebuilt. Everything else is deferred to the production state. On a large project this can reduce CI run time from 30 minutes to under 2 minutes.

---

## How the tools fit together

```
Developer commits
      │
      ▼
pre-commit hooks ── catches style issues locally, instantly
      │
      ▼ (git push → PR opened)
      │
      ├── GitHub Actions: lint ── SQLFluff across all SQL files
      │
      ├── GitHub Actions: bouncer ── naming, docs, test coverage
      │
      ├── GitHub Actions: dbt build ── modified models only, isolated schema
      │
      └── dbt Cloud CI ── same slim build, zero infra, native GitHub integration
```

Using both GitHub Actions and dbt Cloud CI is intentional for a demo — in practice, most teams pick one. dbt Cloud CI is the simpler choice if you're already on dbt Cloud.
