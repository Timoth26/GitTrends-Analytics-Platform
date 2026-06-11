import logging

import boto3
import requests

s3_client = boto3.client("s3")


def file_exists(bucket_name: str, key: str) -> bool:
    try:
        s3_client.head_object(Bucket=bucket_name, Key=key)
        return True
    except s3_client.exceptions.ClientError:
        return False


def download_and_upload_to_s3(
    year: str,
    month: str,
    day: str,
    hour: str,
    bucket_name: str,
) -> str:

    url = f"https://data.gharchive.org/{year}-{month}-{day}-{hour}.json.gz"

    s3_key = (
        f"bronze/year={year}/month={month}/day={day}/"
        f"{year}-{month}-{day}-{hour}.json.gz"
    )

    logging.info(f"Processing: {url}")

    if file_exists(bucket_name, s3_key):
        logging.info(f"Skipping existing file: s3://{bucket_name}/{s3_key}")
        return f"s3://{bucket_name}/{s3_key}"

    try:
        response = requests.get(
            url,
            stream=True,
            timeout=300,
        )
        response.raise_for_status()

        logging.info(f"Uploading: s3://{bucket_name}/{s3_key}")

        s3_client.upload_fileobj(
            Fileobj=response.raw,
            Bucket=bucket_name,
            Key=s3_key,
        )

        return f"s3://{bucket_name}/{s3_key}"

    except requests.RequestException as e:
        logging.error(f"Download failed: {url} | {e}")
        raise

    except Exception as e:
        logging.error(f"Unexpected error for {url}: {e}")
        raise
