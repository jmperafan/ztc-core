WITH reservations AS (
    SELECT * FROM {{ ref("stg_reservations") }}
),

final AS (
    SELECT
        reservation_id,
        reservation_date,
        reservation_start,
        reservation_end,
        TO_CHAR(reservation_start, 'HH24:MI:SS')::time AS start_time,
        TO_CHAR(reservation_end, 'HH24:MI:SS')::time AS end_time,
        CAST(court_number AS NUMBER(38,0)) AS court_number,
        reservation_type,
        event_description,
        CAST(DATEDIFF('minute', reservation_start, reservation_end) AS NUMBER(38,0)) AS duration_in_mins
    FROM reservations
)

SELECT * FROM final
