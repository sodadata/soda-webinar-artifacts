# Databricks notebook source
pip install soda-databricks

# COMMAND ----------

dbutils.library.restartPython()

# COMMAND ----------

dbutils.widgets.text("dataset_identifier", "databricks/unity_catalog/soda_demo/finance_customers")


# COMMAND ----------

from soda_core.contracts import verify_contract_on_agent
dataset_identifier = dbutils.widgets.get("dataset_identifier")
result = verify_contract_on_agent(
    dataset_identifier=dataset_identifier,
    soda_cloud_file_path="/Workspace/Users/tyler.adkins@soda.io/databricks-webinar-feb17/sc.yml"
)