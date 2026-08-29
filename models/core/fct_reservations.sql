WITH reservations AS (
    SELECT * FROM {{ ref("int_reservations_enriched") }}
),

final AS (
    SELECT
        reservation_id,
        reservation_date,
        reservation_start,
        reservation_end,
        start_time,
        end_time,
        court_number,
        reservation_type,
        event_description,
        duration_in_mins
    FROM reservations
)

SELECT * FROM final
