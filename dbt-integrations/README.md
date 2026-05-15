# dbt platform API integration examples

Reference notes on integrating the dbt platform API with Databricks and Power BI.

The actual code has been migrated into the codebase. This folder is now a pointer.

## Python scripts → [scripts/integrations/](../scripts/integrations/)

| Script | Purpose |
|--------|---------|
| [databricks_trigger.py](../scripts/integrations/databricks_trigger.py) | Trigger a dbt job from a Databricks notebook |
| [dbt_to_powerbi_refresh.py](../scripts/integrations/dbt_to_powerbi_refresh.py) | Poll dbt run status, then refresh a Power BI dataset |
| [full_chain_with_webhook.py](../scripts/integrations/full_chain_with_webhook.py) | Full chain + FastAPI webhook receiver alternative |

These keep their original placeholder credentials — they are reference examples, not runnable as-is. Replace placeholders with env vars / secret managers before adapting.

## GitHub Actions workflows → [.github/workflows/](../.github/workflows/)

| Workflow | Trigger |
|----------|---------|
| [dbt-cloud-ci.yml](../.github/workflows/dbt-cloud-ci.yml) | Pull request — runs the dbt platform CI job and posts result to the PR |
| [dbt-deploy.yml](../.github/workflows/dbt-deploy.yml) | Push to main — runs the production dbt job, then refreshes Power BI (Power BI step skips cleanly when PBI_* secrets are not configured) |
| [dbt-manual.yml](../.github/workflows/dbt-manual.yml) | `workflow_dispatch` — manually run a dbt job with custom cause and optional `steps_override` |

The migrated workflows use this project's existing `DBT_CLOUD_*` secret/variable naming, the [`dbt-labs/dbt-cloud-job-action`](https://github.com/dbt-labs/dbt-cloud-job-action) where applicable, and the secret-skip-hardening pattern shared by the other workflows in this repo (a missing secret causes a clean skip rather than a hard failure).

## Required secrets

| Secret | Used in |
|--------|---------|
| `DBT_CLOUD_API_TOKEN` | all dbt workflows |
| `DBT_CLOUD_ACCOUNT_ID` | all dbt workflows |
| `DBT_CLOUD_CI_JOB_ID` | dbt-cloud-ci.yml |
| `DBT_CLOUD_PROD_JOB_ID` | dbt-deploy.yml, dbt-manual.yml, bouncer.yml |
| `PBI_TENANT_ID` | dbt-deploy.yml (optional) |
| `PBI_CLIENT_ID` | dbt-deploy.yml (optional) |
| `PBI_CLIENT_SECRET` | dbt-deploy.yml (optional) |
| `PBI_WORKSPACE_ID` | dbt-deploy.yml (optional) |
| `PBI_DATASET_ID` | dbt-deploy.yml (optional) |

## Required variables

| Variable | Used in |
|----------|---------|
| `DBT_CLOUD_BASE_URL` | all dbt workflows (e.g. `https://de392.us1.dbt.com`) |

Add these under **Settings → Secrets and variables → Actions** in the GitHub repo.

## dbt run status codes

| Code | Meaning |
|------|---------|
| 1 | Queued |
| 2 | Starting |
| 3 | Running |
| 10 | Success |
| 20 | Error |
| 30 | Cancelled |

## References

- [dbt platform API v2](https://docs.getdbt.com/dbt-cloud/api-v2)
- [dbt-labs/dbt-cloud-job-action](https://github.com/dbt-labs/dbt-cloud-job-action)
- [dbt docs — Databricks + dbt guide](https://docs.getdbt.com/guides/how-to-use-databricks-workflows-to-run-dbt-cloud-jobs)
- [dbt docs — webhooks](https://docs.getdbt.com/docs/deploy/webhooks)
