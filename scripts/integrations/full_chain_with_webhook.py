# Full end-to-end chain: Databricks → dbt platform → Power BI
# Includes both a polling orchestrator (Option A)
# and a FastAPI webhook receiver (Option B).

import enum
import os
import time

import requests


# Shared status enum (documented integer codes)
class DbtRunStatus(enum.IntEnum):
    QUEUED = 1
    STARTING = 2
    RUNNING = 3
    SUCCESS = 10
    ERROR = 20
    CANCELLED = 30


class DbtPlatformClient:
    def __init__(self, token, account_id):
        self.base = f"https://cloud.getdbt.com/api/v2/accounts/{account_id}"
        self.headers = {"Authorization": f"Token {token}"}

    def trigger(self, job_id, cause=""):
        r = requests.post(
            f"{self.base}/jobs/{job_id}/run/",
            headers=self.headers,
            json={"cause": cause},
        )
        r.raise_for_status()
        return r.json()["data"]["id"]

    def wait(self, run_id, interval=30):
        url = f"{self.base}/runs/{run_id}/"
        while True:
            d = requests.get(url, headers=self.headers).json()["data"]
            status = DbtRunStatus(d["status"])
            print(f"[dbt] {status.name}")
            if status == DbtRunStatus.SUCCESS:
                return True
            if status in (DbtRunStatus.ERROR, DbtRunStatus.CANCELLED):
                raise RuntimeError(f"dbt job failed: {status.name}")
            time.sleep(interval)


def pbi_refresh(tenant, client_id, secret, workspace, dataset):
    token = requests.post(
        f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": secret,
            "scope": "https://analysis.windows.net/powerbi/api/.default",
        },
    ).json()["access_token"]
    requests.post(
        f"https://api.powerbi.com/v1.0/myorg/groups/{workspace}/datasets/{dataset}/refreshes",
        headers={"Authorization": f"Bearer {token}"},
        json={"notifyOption": "MailOnFailure"},
    ).raise_for_status()


# Option A: polling orchestrator
dbt = DbtPlatformClient(os.environ["DBT_TOKEN"], "12345")
run = dbt.trigger("67890", cause="Databricks silver layer finished")
dbt.wait(run)
pbi_refresh(
    os.environ["TENANT_ID"],
    os.environ["CLIENT_ID"],
    os.environ["CLIENT_SECRET"],
    "<workspace-id>",
    "<dataset-id>",
)


# Option B: webhook receiver (FastAPI)
# Deploy this as a cloud function. In dbt platform job settings →
# Notifications, add your endpoint URL as a webhook.

from fastapi import FastAPI, Request

app = FastAPI()


@app.post("/webhook/dbt")
async def dbt_webhook(req: Request):
    body = await req.json()
    event_type = body.get("eventType")
    run_status = body.get("data", {}).get("runStatus")

    if event_type == "job.run.completed" and run_status == "Success":
        pbi_refresh(
            os.environ["TENANT_ID"],
            os.environ["CLIENT_ID"],
            os.environ["CLIENT_SECRET"],
            "<workspace-id>",
            "<dataset-id>",
        )
    return {"received": True}
