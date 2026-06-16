import os

from airflow.sdk import dag, get_current_context, task
from dotenv import load_dotenv
from gittrends.ingestion.api import download_and_upload_to_s3
from pendulum import datetime

load_dotenv()
BUCKET_NAME = os.getenv("BUCKET_NAME")


@dag(
    schedule="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["portfolio", "ingestion", "bronze"],
    max_active_runs=1,
)
def gharchive_ingestion():

    @task
    def generate_hourly_params() -> list[dict]:
        context = get_current_context()
        logical_date = context["logical_date"]

        year = logical_date.strftime("%Y")
        month = logical_date.strftime("%m")
        day = logical_date.strftime("%d")

        return [
            {
                "year": year,
                "month": month,
                "day": day,
                "hour": f"{hour:02d}",
            }
            for hour in range(24)
        ]

    @task
    def process_hour(hour_params: dict, bucket_name: str) -> str:
        return download_and_upload_to_s3(
            year=hour_params["year"],
            month=hour_params["month"],
            day=hour_params["day"],
            hour=hour_params["hour"],
            bucket_name=bucket_name,
        )

    hourly_params = generate_hourly_params()

    process_hour.partial(bucket_name=BUCKET_NAME).expand(hour_params=hourly_params)


gharchive_ingestion()
