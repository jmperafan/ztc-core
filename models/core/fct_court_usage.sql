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
        TIME '{{ var("closing_time") }}' AS start_time,
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
        TIME '{{ var("opening_time") }}' AS end_time,
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
            court_number::varchar,
            '_',
            reservation_date::varchar,
            '_',
            start_time::varchar
        ) AS slot_key,
        *,
        {{ is_winter_break("reservation_date") }} AS is_winter_break
    FROM unioned
    -- Overlapping reservations in the source (same court/date/start_time) produce
    -- duplicate slot_keys. Keep one row per slot, preferring actual bookings
    -- (reservation_id not null) over gap-fill rows.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY court_number, reservation_date, start_time
        ORDER BY reservation_id NULLS LAST
    ) = 1
)

SELECT * FROM final
