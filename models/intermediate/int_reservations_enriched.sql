WITH reservations AS (
    SELECT * FROM {{ ref('int_reservations') }}
),

final AS (
    -- Explicit casts pin the output types that fct_reservations publishes under
    -- contract. stg_reservations has no contract, so in a deferred build the
    -- upstream's inferred types (NUMBER/REAL) would otherwise leak through and
    -- break contract validation. The casts live here rather than in
    -- fct_reservations so that intermediate consumers get the same types
    -- without depending on the core layer.
    SELECT
        reservation_id::varchar AS reservation_id,
        reservation_date,
        reservation_start,
        reservation_end,
        TO_CHAR(reservation_start, 'HH24:MI:SS')::time AS start_time,
        TO_CHAR(reservation_end, 'HH24:MI:SS')::time AS end_time,
        court_number::number(2, 0) AS court_number,
        reservation_type,
        event_description,
        (
            DATEDIFF('minute', reservation_start, reservation_end)
        )::number(38, 0) AS duration_in_mins
    FROM reservations
)

SELECT * FROM final
