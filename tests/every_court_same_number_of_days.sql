{{ config(severity='error') }}

WITH fct_court_usage AS (
    SELECT * FROM {{ ref('fct_court_usage') }}
),

count_of_days AS (
    SELECT COUNT(DISTINCT reservation_date) AS n
    FROM fct_court_usage
),

days_per_court AS (
    SELECT
        court_number,
        COUNT(DISTINCT reservation_date) AS n
    FROM {{ ref('fct_court_usage') }}
    GROUP BY ALL
)

SELECT * FROM days_per_court
WHERE n != (
    SELECT n FROM count_of_days
)
