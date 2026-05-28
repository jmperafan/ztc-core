# Databricks notebook cell (Python)
# Confirmed endpoint: https://docs.getdbt.com/guides/how-to-use-databricks-workflows-to-run-dbt-cloud-jobs


import dbutils
import requests

DBT_ACCOUNT_ID = "12345"
DBT_JOB_ID = "67890"
DBT_TOKEN = dbutils.secrets.get(scope="dbt", key="service-token")

BASE_URL = f"https://cloud.getdbt.com/api/v2/accounts/{DBT_ACCOUNT_ID}"
HEADERS = {
    "Authorization": f"Token {DBT_TOKEN}",
    "Content-Type": "application/json",
}


def trigger_dbt_job(cause: str = "Triggered by Databricks workflow") -> dict:
    resp = requests.post(
        f"{BASE_URL}/jobs/{DBT_JOB_ID}/run/",
        headers=HEADERS,
        json={"cause": cause},
    )
    resp.raise_for_status()
    return resp.json()["data"]


run = trigger_dbt_job("silver layer complete — starting dbt transformations")
print(f"dbt run started: id={run['id']}")
