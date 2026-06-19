import json

from gittrends.databricks.bronze_to_silver import clean_and_flatten_data


def test_clean_and_flatten_data_explodes_commits_and_filters(spark):

    mock_data = [
        # EVENT 1: PushEvent with two commits
        json.dumps(
            {
                "id": "1001",
                "type": "PushEvent",
                "actor": {"login": "octocat"},
                "repo": {"name": "apache/spark"},
                "created_at": "2026-06-19T10:00:00Z",
                "payload": {
                    "action": "created",
                    "size": 2,
                    "commits": [
                        {"message": "Pierwszy commit", "author": {"name": "Alice"}},
                        {"message": "Drugi commit", "author": {"name": "Bob"}},
                    ],
                },
            }
        ),
        # EVENT 2: ID missing
        json.dumps(
            {
                "id": None,
                "type": "WatchEvent",
                "actor": {"login": "janedoe"},
                "repo": {"name": "aws/aws-cli"},
                "created_at": "2026-06-19T11:00:00Z",
                "payload": {},
            }
        ),
    ]

    rdd = spark.sparkContext.parallelize(mock_data)
    df_bronze = spark.read.json(rdd)

    df_silver = clean_and_flatten_data(df_bronze)
    results = df_silver.collect()

    assert len(results) == 2

    assert results[0]["event_id"] == "1001"
    assert results[0]["commit_author"] == "Alice"
    assert results[0]["commit_message"] == "Pierwszy commit"

    assert results[1]["event_id"] == "1001"
    assert results[1]["commit_author"] == "Bob"
    assert results[1]["commit_message"] == "Drugi commit"

    assert results[0]["actor_login"] == "octocat"
