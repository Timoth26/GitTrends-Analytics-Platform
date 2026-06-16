{{ config(
    materialized='table',
    format='parquet',
    partitioned_by=['event_date'],
    s3_data_dir='s3://gittrends-data-lake/gold/fact_daily_commits/'
) }}

WITH source_data AS (
    SELECT * FROM {{ source('silver_layer', 'github_events') }}
)

SELECT 
    repo_name,
    actor_login AS author,
    COUNT(event_id) AS total_commits,
    DATE(created_at) AS event_date
FROM source_data
WHERE event_type = 'PushEvent' 
  AND repo_name IS NOT NULL
GROUP BY 
    repo_name,
    actor_login,
    DATE(created_at)