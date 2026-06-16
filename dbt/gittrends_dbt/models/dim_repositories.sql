{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://gittrends-data-lake/gold/dim_repositories/'
) }}

WITH source_data AS (
    SELECT * FROM {{ source('silver_layer', 'github_events') }}
)

SELECT 
    repo_name,
    CAST(MIN(created_at) AS TIMESTAMP) AS first_event_at,
    CAST(MAX(created_at) AS TIMESTAMP) AS last_event_at
FROM source_data
WHERE repo_name IS NOT NULL
GROUP BY repo_name