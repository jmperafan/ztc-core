with reservations as (
    select * from {{ ref("stg_reservations") }}
),

final as (
    select
        reservation_id,
        reservation_date,
        reservation_start,
        reservation_end,
        TO_CHAR(reservation_start, 'HH24:MI:SS')::time as start_time,
        TO_CHAR(reservation_end, 'HH24:MI:SS')::time as end_time,
        DATEDIFF('minute', reservation_start, reservation_end) as duration_in_mins,
        court_number,
        reservation_type,
        event_description
    from reservations
)

select * from final
