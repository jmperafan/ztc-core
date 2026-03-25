WITH hours AS (
    SELECT SEQ4() AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 24))
)

SELECT
    DATEADD('hour', hours.n, dim_calendar.date_key::timestamp) AS datetime_hour
FROM {{ ref('dim_calendar') }}
CROSS JOIN hours
