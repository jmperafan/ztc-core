WITH

int_court_slots AS (
    SELECT * FROM {{ ref('int_court_slots') }}
),

filtered AS (
    SELECT *
    FROM int_court_slots
    WHERE NOT is_winter_break
),

final AS (
    SELECT
        CONCAT(
            court_number::varchar, '_', reservation_date::varchar
        ) AS daily_court_key,
        court_number,
        reservation_date,
        COUNT_IF(reservation_type = 'Gereserveerd') AS booked_slots,
        COUNT_IF(reservation_type = 'Beschikbaar') AS available_slots,
        COUNT_IF(reservation_type IN ('Gereserveerd', 'Beschikbaar')) AS total_playable_slots,
        SUM(
            CASE
                WHEN reservation_type = 'Gereserveerd'
                    THEN duration_in_mins
                ELSE 0
            END
        ) AS booked_minutes,
        SUM(
            CASE
                WHEN reservation_type IN ('Gereserveerd', 'Beschikbaar')
                    THEN duration_in_mins
                ELSE 0
            END
        ) AS available_minutes,
        ROUND(
            COUNT_IF(reservation_type = 'Gereserveerd') * 100.0
            / NULLIF(COUNT_IF(reservation_type IN ('Gereserveerd', 'Beschikbaar')), 0),
            2
        ) AS utilization_pct
    FROM filtered
    GROUP BY 1, 2, 3
)

SELECT * FROM final
