{{ config(severity='warn') }}

SELECT
    court_number,
    reservation_date,
    SUM(duration_in_mins) AS total_duration_in_mins
FROM {{ ref('fct_court_usage') }}
GROUP BY ALL
HAVING SUM(duration_in_mins) != 1440
