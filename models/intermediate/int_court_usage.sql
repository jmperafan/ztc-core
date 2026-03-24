with reservations as (
  -- One row per reservation
  select
    reservation_id,
    court_number,
    reservation_date,
    start_time,
    end_time,
    reservation_type,
    event_description
  from {{ ref('fct_reservations') }}
),

window_function as (
  select
    court_number,
    reservation_date,
    start_time,
    end_time,
    lead(start_time, 1) over (
      partition by reservation_date, court_number
      order by start_time
    ) as lead
  from reservations
),

unused_hours as (
  -- One row per gap between reservations
  select
    null as reservation_id,
    court_number,
    reservation_date,
    end_time as start_time,
    lead as end_time,
    'Beschikbaar' as reservation_type,
    'Niet geboekt' as event_description
  from window_function
  where end_time != lead
),

first_hour as (
  -- One row if the first booking is not at opening time
  select
    null as reservation_id,
    court_number,
    reservation_date,
    {{ var('opening_time') }} as start_time,
    MIN(start_time) as end_time,
    'Beschikbaar' as reservation_type,
    'Club niet open' as event_description
  from reservations
  group by court_number, reservation_date
  having MIN(start_time) != {{ var("opening_time") }}
),

last_hour as (
  -- One row if the last booking is not at closing time
  select
    null as reservation_id,
    court_number,
    reservation_date,
    MAX(end_time) as start_time,
    {{ var('closing_time') }} as end_time,
    'Beschikbaar' as reservation_type,
    'Club niet open' as event_description
  from reservations
  group by court_number, reservation_date
  having MAX(end_time) != {{ var('closing_time') }}
),

empty_days as (
  -- One row if a court hasn't been booked on a certain date
  select
    null as reservation_id,
    spine.court_number,
    spine.reservation_date,
    {{ var('opening_time') }} as start_time,
    {{ var('closing_time') }} as end_time,
    'Beschikbaar' as reservation_type,
    'Niet geboekt' as event_description
  from {{ ref('int_court_date_spine') }} as spine
  left join reservations
    on spine.reservation_date = reservations.reservation_date
    and spine.court_number = reservations.court_number
  where reservations.reservation_type is null
),

unioned as (
  select * from reservations
  union select * from first_hour
  union select * from last_hour
  union select * from unused_hours
  union select * from empty_days
)

select * from unioned
