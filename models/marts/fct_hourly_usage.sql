with source as (
    select * from {{ ref('fct_court_usage') }}
    where is_winter_break = false
),

hourly as (
    select
        reservation_id,
        court_number,
        reservation_date,
        HOUR(start_time) as start_hour,
        start_time,
        reservation_type,
        event_description
    from source
)

select * from hourly
