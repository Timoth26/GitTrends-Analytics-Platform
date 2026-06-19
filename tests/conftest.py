import pytest
from pyspark.sql import SparkSession


@pytest.fixture(scope="session")
def spark():

    spark_session = (
        SparkSession.builder.master("local[1]")
        .appName("pytest-pyspark")
        .config("spark.sql.shuffle.partitions", "1")
        .getOrCreate()
    )

    yield spark_session

    spark_session.stop()
