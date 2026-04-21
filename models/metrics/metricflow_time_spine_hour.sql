WITH dim_calendar AS (
    SELECT * FROM {{ ref('dim_calendar') }}
),

hours AS (
    SELECT SEQ4() AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 24))
),

final AS (
    SELECT DATEADD('hour', hours.n, dim_calendar.date_key::timestamp) AS datetime_hour
    FROM dim_calendar
    CROSS JOIN hours
)

SELECT * FROM final
