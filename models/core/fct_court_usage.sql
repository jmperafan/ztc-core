with

working_hours as (
  select
    reservation_id,
    court_number,
    reservation_date,
    start_time,
    end_time,
    reservation_type,
    event_description,
    DATEDIFF('minute', start_time::time, end_time::time) as duration_in_mins
  from {{ ref('int_court_usage') }}
),

midnight_closed_hours as (
  select
    null as reservation_id,
    court_number,
    reservation_date,
    {{ var('closing_time') }} as start_time,
    TIME '00:00:00' as end_time,
    'Gesloten' as reservation_type,
    'Club niet open' as event_description,
    60 as duration_in_mins
  from {{ ref('int_court_date_spine') }}
),

morning_closed_hours as (
  select
    null as reservation_id,
    court_number,
    reservation_date,
    TIME '00:00:00' as start_time,
    {{ var('opening_time') }} as end_time,
    'Gesloten' as reservation_type,
    'Club niet open' as event_description,
    480 as duration_in_mins
  from {{ ref('int_court_date_spine') }}
),

unioned as (
  select * from working_hours
  union select * from midnight_closed_hours
  union select * from morning_closed_hours
),

final as (
  select
    *,
    {{ is_winter_break("reservation_date") }} as is_winter_break
  from unioned
)

select * from final
