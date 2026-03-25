WITH

working_hours AS (
    SELECT
        reservation_id,
        court_number,
        reservation_date,
        start_time,
        end_time,
        reservation_type,
        event_description,
        DATEDIFF('minute', start_time::time, end_time::time) AS duration_in_mins
    FROM {{ ref('int_court_usage') }}
),

midnight_closed_hours AS (
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        {{ var('closing_time') }} AS start_time,
        TIME '00:00:00' AS end_time,
        'Gesloten' AS reservation_type,
        'Club niet open' AS event_description,
        60 AS duration_in_mins
    FROM {{ ref('int_court_date_spine') }}
),

morning_closed_hours AS (
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        TIME '00:00:00' AS start_time,
        {{ var('opening_time') }} AS end_time,
        'Gesloten' AS reservation_type,
        'Club niet open' AS event_description,
        480 AS duration_in_mins
    FROM {{ ref('int_court_date_spine') }}
),

unioned AS (
    SELECT * FROM working_hours
    UNION DISTINCT
    SELECT * FROM midnight_closed_hours
    UNION DISTINCT
    SELECT * FROM morning_closed_hours
),

final AS (
    SELECT
        CONCAT(
            CAST(court_number AS VARCHAR),
            '_',
            CAST(reservation_date AS VARCHAR),
            '_',
            CAST(start_time AS VARCHAR)
        ) AS slot_key,
        *,
        {{ is_winter_break("reservation_date") }} AS is_winter_break
    FROM unioned
)

SELECT * FROM final
