SELECT 
    repo_name,
    author,
    event_date
FROM {{ ref('fact_daily_commits') }}
WHERE event_date > CURRENT_DATE