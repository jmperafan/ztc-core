WITH reservations AS (
    SELECT * FROM {{ ref("stg_reservations") }}
),

final AS (
    -- Explicit cast pins reservation_id to the VARCHAR declared in _models.yml.
    -- stg_reservations has no contract, so in a deferred build the upstream's
    -- inferred type (NUMBER) leaks through and breaks contract validation.
    SELECT
        reservation_id::varchar AS reservation_id,
        reservation_date,
        reservation_start,
        reservation_end,
        TO_CHAR(reservation_start, 'HH24:MI:SS')::time AS start_time,
        TO_CHAR(reservation_end, 'HH24:MI:SS')::time AS end_time,
        court_number::number(38, 0) AS court_number,
        reservation_type,
        event_description,
        (DATEDIFF('minute', reservation_start, reservation_end))::number(38, 0) AS duration_in_mins
    FROM reservations
)

SELECT * FROM final
