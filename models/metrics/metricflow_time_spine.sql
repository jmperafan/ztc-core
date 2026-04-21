WITH dim_calendar AS (
    SELECT * FROM {{ ref('dim_calendar') }}
),

final AS (
    SELECT date_key AS date_day
    FROM dim_calendar
)

SELECT * FROM final
