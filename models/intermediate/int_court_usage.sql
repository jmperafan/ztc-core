WITH fct_reservations AS (
    SELECT * FROM {{ ref('fct_reservations') }}
),

int_court_date_spine AS (
    SELECT * FROM {{ ref('int_court_date_spine') }}
),

reservations AS (
    -- One row per reservation, limited to operating hours and deduplicated to remove
    -- overlapping bookings. Overlaps break the gap-fill logic: the LEAD window only
    -- looks at the next start_time, so a reservation that starts inside an existing
    -- one causes the gap after the first booking to be miscalculated.
    -- We keep the greedy non-overlapping set: a reservation is kept only if its
    -- start_time is >= the latest end_time of all prior reservations on that court/date.
    SELECT
        reservation_id,
        court_number,
        reservation_date,
        start_time,
        end_time,
        reservation_type,
        event_description
    FROM fct_reservations
    WHERE
        start_time >= {{ var('opening_time') }}
        AND end_time <= {{ var('closing_time') }}
        AND end_time > start_time
    QUALIFY start_time >= COALESCE(
        MAX(end_time) OVER (
            PARTITION BY court_number, reservation_date
            ORDER BY start_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ),
        start_time
    )
),

window_function AS (
    SELECT
        court_number,
        reservation_date,
        start_time,
        end_time,
        LEAD(start_time, 1) OVER (
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
        MIN(start_time) AS end_time,
        'Beschikbaar' AS reservation_type,
        'Club niet open' AS event_description
    FROM reservations
    GROUP BY court_number, reservation_date
    HAVING MIN(start_time) != {{ var("opening_time") }}
),

last_hour AS (
    -- One row if the last booking is not at closing time
    SELECT
        NULL AS reservation_id,
        court_number,
        reservation_date,
        MAX(end_time) AS start_time,
        {{ var('closing_time') }} AS end_time,
        'Beschikbaar' AS reservation_type,
        'Club niet open' AS event_description
    FROM reservations
    GROUP BY court_number, reservation_date
    HAVING MAX(end_time) != {{ var('closing_time') }}
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
    FROM int_court_date_spine AS spine
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
