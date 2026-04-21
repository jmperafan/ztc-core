-- High Watermark incremental pattern demo.
--
-- Compare with the other incremental models in this project:
--   fct_reservation_events   → microbatch (dbt manages the window automatically)
--   fct_daily_court_stats    → delete+insert with MAX(col) FROM {{ this }}
--   fct_hourly_weather_usage → merge with MAX(col) FROM {{ this }}
--
-- The HWM pattern stores the exact upper bound used on each run in a central
-- watermark table. This means every processing window is mutually exclusive and
-- collectively exhaustive — unlike MAX(col) FROM {{ this }}, the upper bound is
-- captured before the model runs, not derived from what already landed in the
-- target table.
--
-- First run: no watermark exists, so get_previous_hwm() returns '1900-01-01'
-- and the model processes all rows (full refresh equivalent).
-- Subsequent runs: processes only rows strictly between the last committed
-- watermark and the current max snapshotted at run start.

{{
  config(
    materialized='incremental',
    unique_key='reservation_id',
    incremental_strategy='merge',
    pre_hook="{{ set_job_param() }}",
    post_hook="{{ update_job_param(success=true) }}",
    meta={'hwm_field': 'reservation_date', 'hwm_source_model': 'fct_reservations'}
  )
}}

with fct_reservations as (
    select * from {{ ref('fct_reservations') }}
),

bridge_member_reservations as (
    select * from {{ ref('bridge_member_reservations') }}
),

dim_members_anonimized as (
    select * from {{ ref('dim_members_anonimized') }}
),

fct_weather as (
    select * from {{ ref('fct_weather') }}
),

reservations as (

    select
        reservation_id,
        reservation_date,
        court_number,
        start_time,
        end_time,
        duration_in_mins,
        reservation_type,
        event_description,
        dayofweek(reservation_date)     as day_of_week,
        dayname(reservation_date)       as day_of_week_name,
        hour(start_time)                as start_hour
    from fct_reservations
    where reservation_type = 'Gereserveerd'

    {% if is_incremental() %}
    -- get_previous_hwm: last committed upper bound from the watermark table
    -- get_current_hwm:  max(reservation_date) snapshotted by the pre-hook at run start
    and reservation_date between ({{ get_previous_hwm(ref('fct_reservations')) }})
                             and ({{ get_current_hwm(ref('fct_reservations')) }})
    {% endif %}

),

member_bridge as (
    select reservation_id, member_id
    from bridge_member_reservations
),

member_profiles as (
    select
        member_id,
        gender,
        age_group,
        city,
        current_type_of_membership,
        is_club_member,
        is_knltb_member
    from dim_members_anonimized
),

weather as (
    select
        date(datetime)  as weather_date,
        hour(datetime)  as weather_hour,
        temperature,
        precipitation,
        wind_speed,
        ideal_weather
    from fct_weather
),

final as (
    select
        r.reservation_id,
        r.reservation_date,
        r.court_number,
        r.start_time,
        r.end_time,
        r.duration_in_mins,
        r.day_of_week,
        r.day_of_week_name,
        r.start_hour,
        b.member_id,
        p.gender,
        p.age_group,
        p.city,
        p.current_type_of_membership,
        p.is_club_member,
        p.is_knltb_member,
        w.temperature,
        w.precipitation,
        w.wind_speed,
        w.ideal_weather
    from reservations r
    left join member_bridge b   on r.reservation_id = b.reservation_id
    left join member_profiles p on b.member_id      = p.member_id
    left join weather w         on r.reservation_date = w.weather_date
                                and r.start_hour      = w.weather_hour
)

select * from final
