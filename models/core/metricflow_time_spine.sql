SELECT date_key AS date_day
FROM {{ ref('dim_calendar') }}
