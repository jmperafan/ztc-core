WITH reservations AS (
    -- One row per reservation
    SELECT
        reservation_id,
        court_number,
        reservation_date,
        start_time,
        end_time,
        reservation_type,
        event_description
    FROM {{ ref('fct_reservations') }}
),

window_function AS (
    SELECT
        court_number,
        reservation_date,
        start_time,
        end_time,
        lead(start_time, 1) OVER (
            PARTITION BY reservation_date, court_number
            ORDER BY start_time
        ) AS lead
    FROM reservations
),

unused_hours AS (
    -- One row per gap between reservations
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        end_time AS start_time,
        lead AS end_time,
        'Beschikbaar' AS reservation_type,
        'Niet geboekt' AS event_description
    FROM window_function
    WHERE end_time < lead
),

first_hour AS (
    -- One row if the first booking is not at opening time
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        {{ var('opening_time') }} AS start_time,
        min(start_time) AS end_time,
        'Beschikbaar' AS reservation_type,
        'Club niet open' AS event_description
    FROM reservations
    GROUP BY court_number, reservation_date
    HAVING min(start_time) != {{ var("opening_time") }}
),

last_hour AS (
    -- One row if the last booking is not at closing time
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        max(end_time) AS start_time,
        {{ var('closing_time') }} AS end_time,
        'Beschikbaar' AS reservation_type,
        'Club niet open' AS event_description
    FROM reservations
    GROUP BY court_number, reservation_date
    HAVING max(end_time) != {{ var('closing_time') }}
),

empty_days AS (
    -- One row if a court hasn't been booked on a certain date
    SELECT
        NULL AS reservation_id,
        spine.court_number,
        spine.reservation_date,
        {{ var('opening_time') }} AS start_time,
        {{ var('closing_time') }} AS end_time,
        'Beschikbaar' AS reservation_type,
        'Niet geboekt' AS event_description
    FROM {{ ref('int_court_date_spine') }} AS spine
    LEFT JOIN reservations
        ON
            spine.reservation_date = reservations.reservation_date
            AND spine.court_number = reservations.court_number
    WHERE reservations.reservation_type IS NULL
),

unioned AS (
    SELECT * FROM reservations
    UNION DISTINCT
    SELECT * FROM first_hour
    UNION DISTINCT
    SELECT * FROM last_hour
    UNION DISTINCT
    SELECT * FROM unused_hours
    UNION DISTINCT
    SELECT * FROM empty_days
)

SELECT * FROM unioned
