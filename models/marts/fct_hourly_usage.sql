WITH source AS (
    SELECT * FROM {{ ref('fct_court_usage') }}
    WHERE is_winter_break = FALSE
),

hourly AS (
    SELECT
        reservation_id,
        court_number,
        reservation_date,
        start_time,
        reservation_type,
        event_description,
        HOUR(start_time) AS start_hour
    FROM source
)

SELECT * FROM hourly
