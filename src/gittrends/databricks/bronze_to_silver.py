# Databricks notebook source
import os

from dotenv import load_dotenv
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.functions import col, explode_outer, lit, to_timestamp
from pyspark.sql.types import StructType

load_dotenv()
BUCKET_NAME = os.getenv("BUCKET_NAME")


def clean_and_flatten_data(df_bronze: DataFrame) -> DataFrame:
    payload_schema = df_bronze.schema["payload"].dataType
    payload_fields = (
        payload_schema.names if isinstance(payload_schema, StructType) else []
    )

    action_col = (
        col("payload.action")
        if "action" in payload_fields
        else lit(None).cast("string")
    )
    size_col = (
        col("payload.size") if "size" in payload_fields else lit(None).cast("long")
    )

    if "commits" in payload_fields:
        df_exploded = df_bronze.withColumn(
            "commit", explode_outer(col("payload.commits"))
        )
        commit_message_col = col("commit.message")
        commit_author_col = col("commit.author.name")
    else:
        df_exploded = df_bronze
        commit_message_col = lit(None).cast("string")
        commit_author_col = lit(None).cast("string")

    df_silver = df_exploded.select(
        col("id").alias("event_id"),
        col("type").alias("event_type"),
        col("actor.login").alias("actor_login"),
        col("repo.name").alias("repo_name"),
        to_timestamp(col("created_at")).alias("created_at"),
        action_col.alias("action_type"),
        size_col.alias("push_size"),
        commit_message_col.alias("commit_message"),
        commit_author_col.alias("commit_author"),
    )

    return df_silver.filter(col("repo_name").isNotNull() & col("event_id").isNotNull())


def main():
    spark = SparkSession.builder.appName("GitHubArchive-BronzeToSilver").getOrCreate()

    BUCKET_NAME = "BUCKET_NAME"
    BRONZE_PATH = f"s3://{BUCKET_NAME}/bronze/*/*/*/*.json.gz"
    SILVER_PATH = f"s3://{BUCKET_NAME}/silver/github_events/"

    print(f"Load raw data from: {BRONZE_PATH}")
    df_raw = spark.read.json(BRONZE_PATH)

    df_cleaned = clean_and_flatten_data(df_raw)

    print("Upload clear data to S3 Delta Lake...")
    df_cleaned.write.format("delta").mode("append").partitionBy("event_type").save(
        SILVER_PATH
    )

    print("Register table in Unity Catalog...")
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS default.github_events_silver 
        USING DELTA 
        LOCATION '{SILVER_PATH}'
    """)

    print("Bronze -> Silver succeeded")


if __name__ == "__main__":
    main()
