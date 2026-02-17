# Databricks notebook source
pip install soda-sparkdf

# COMMAND ----------

dbutils.library.restartPython()

# COMMAND ----------

from soda_core.contracts import verify_contracts_locally
from soda_sparkdf import SparkDataFrameDataSource

df = spark.read.format("csv").option("header","true").load("transactions.csv")
df.createOrReplaceTempView("transactions")

spark_data_source = SparkDataFrameDataSource.from_existing_session(
    session=spark,
    name="databricks"
)

result = verify_contracts_locally(
    data_sources=[spark_data_source],
    contract_file_paths="contract.yml"
)