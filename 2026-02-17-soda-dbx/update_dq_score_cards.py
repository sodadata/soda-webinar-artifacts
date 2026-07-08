# Databricks notebook source
import base64
import os
import requests
base_sc_host = "cloud.us.soda.io"
SODA_CLOUD_BASE_URL = f"https://{base_sc_host}/api/v1"
api_keys = f"{os.environ['SODA_API_KEY_ID']}:{os.environ['SODA_API_KEY_SECRET']}".encode("utf-8")
SODA_CLOUD_BASIC_TOKEN = base64.b64encode(api_keys).decode("ascii")
TIMEOUT_SECONDS = 60

# COMMAND ----------

from pyspark.sql.functions import col, concat_ws, format_string

def get_dataset_urls(data_source: str=None) -> str:
    url = f"{SODA_CLOUD_BASE_URL}/datasets"
    datasets = {}
    page = 0
    while True:
        response = requests.get(
            url=url,
            headers={"Authorization": f"Basic {SODA_CLOUD_BASIC_TOKEN}", "Accept": "*/*"},
            params={"size": 1000, "page": page, "datasourceName": data_source},
            timeout=TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        data = response.json()
        if len(data["content"]) == 0:
            break
        else:
            for dataset in data["content"]:
                dqn = dataset["qualifiedName"]
                datasets[dqn] = dataset["cloudUrl"]
            page += 1
    return datasets


# Read the latest DQ results
dq_df = spark.read.table("unity_catalog.tyler_dwh.latest_scans_dq")

# Collect the relevant columns to the driver
rows = dq_df.select(
    "dataset_qualified_name",
    "check_count",
    "pass_rate",
    "fail_rate",
    "warn_rate",
    "pass_count",
    "fail_count",
    "warn_count"
).collect()


dataset_urls = get_dataset_urls("databricks")

for row in rows:
    # Parse the qualified name to get the catalog.schema.table
    dqn = row['dataset_qualified_name']
    parts = dqn.split('/')
    if len(parts) >= 4:
        table_fqn = f"{parts[1]}.{parts[2]}.{parts[3]}"
    else:
        continue

    if table_fqn not in dataset_urls:
        continue
    else:
        soda_cloud_dataset_url = dataset_urls[table_fqn]

    # Build the scorecard comment
    comment = (
        f"📝 [Soda Data Quality Score]({soda_cloud_dataset_url})\n"
        f"✅ Pass: {row['pass_count']} ({row['pass_rate']*100:.1f}%)\n"
        f"⚠️ Warn: {row['warn_count']} ({row['warn_rate']*100:.1f}%)\n"
        f"❌ Fail: {row['fail_count']} ({row['fail_rate']*100:.1f}%)\n"
        f"🔎 Checks: {row['check_count']}"
    )

    # Update the table comment in Unity Catalog
    spark.sql(f"COMMENT ON TABLE {table_fqn} IS '{comment}'")
    print(f"Added a DQ score card to: {table_fqn}")

# COMMAND ----------

dataset_urls

# COMMAND ----------

