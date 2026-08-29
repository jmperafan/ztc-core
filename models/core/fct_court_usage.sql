WITH

int_court_slots AS (
    SELECT * FROM {{ ref('int_court_slots') }}
),

final AS (
    SELECT
        slot_key,
        reservation_id,
        court_number,
        reservation_date,
        start_time,
        end_time,
        reservation_type,
        event_description,
        duration_in_mins,
        is_winter_break
    FROM int_court_slots
)

SELECT * FROM final
