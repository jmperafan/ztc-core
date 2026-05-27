# Python — run as Databricks task, Lambda, or standalone script
# Polls dbt platform run using documented integer status codes,
# then triggers a Power BI dataset refresh on success.
import enum
import time

import requests


# dbt platform status codes (from API docs)
class DbtRunStatus(enum.IntEnum):
    QUEUED = 1
    STARTING = 2
    RUNNING = 3
    SUCCESS = 10
    ERROR = 20
    CANCELLED = 30


DBT_TOKEN = "dbtst_xxxxxxxxxxxx"
DBT_ACCOUNT_ID = "12345"
DBT_RUN_ID = "99999"  # from trigger_dbt_job() response

# Power BI credentials (use env vars / secrets in production)
TENANT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
CLIENT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
CLIENT_SECRET = "your-service-principal-secret"
PBI_WORKSPACE = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
PBI_DATASET = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"


def wait_for_dbt_run(run_id, poll_seconds=30, timeout=3600):
    url = (
        f"https://cloud.getdbt.com/api/v2/accounts/" f"{DBT_ACCOUNT_ID}/runs/{run_id}/"
    )
    headers = {"Authorization": f"Token {DBT_TOKEN}"}
    elapsed = 0
    while elapsed < timeout:
        data = requests.get(url, headers=headers).json()["data"]
        status = DbtRunStatus(data["status"])
        print(f"  dbt run status: {status.name}")
        if status == DbtRunStatus.SUCCESS:
            return True
        elif status in (DbtRunStatus.ERROR, DbtRunStatus.CANCELLED):
            raise RuntimeError(f"dbt job failed: {status.name}")
        time.sleep(poll_seconds)
        elapsed += poll_seconds
    raise TimeoutError("dbt run did not complete in time")


def get_pbi_token():
    resp = requests.post(
        f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope": "https://analysis.windows.net/powerbi/api/.default",
        },
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def trigger_pbi_refresh():
    token = get_pbi_token()
    resp = requests.post(
        f"https://api.powerbi.com/v1.0/myorg/groups/{PBI_WORKSPACE}"
        f"/datasets/{PBI_DATASET}/refreshes",
        headers={"Authorization": f"Bearer {token}"},
        json={"notifyOption": "MailOnFailure"},
    )
    resp.raise_for_status()
    print("Power BI refresh triggered ✓")


wait_for_dbt_run(DBT_RUN_ID)
trigger_pbi_refresh()
