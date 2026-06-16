{{ config(
    materialized='table',
    format='parquet',
    s3_data_dir='s3://gittrends-data-lake/gold/dim_users/'
) }}

WITH source_data AS (
    SELECT * FROM {{ source('silver_layer', 'github_events') }}
)

SELECT 
    actor_login AS username,
    CAST(MIN(created_at) AS TIMESTAMP) AS first_seen_at,
    CAST(MAX(created_at) AS TIMESTAMP) AS last_seen_at,
    COUNT(DISTINCT repo_name) AS total_repos_contributed_to
FROM source_data
WHERE actor_login IS NOT NULL
GROUP BY actor_login