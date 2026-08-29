{{
  config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='reservation_date',
    batch_size='month',
    lookback=3,
    begin='2022-01-01',
    on_schema_change='fail'
  )
}}

WITH

int_reservation_events AS (
    SELECT * FROM {{ ref('int_reservation_events') }}
),

final AS (
    SELECT
        reservation_id,
        reservation_date,
        court_number,
        start_time,
        end_time,
        duration_in_mins,
        day_of_week,
        day_of_week_name,
        start_hour,
        member_id,
        gender,
        age_group,
        city,
        current_type_of_membership,
        is_club_member,
        is_knltb_member
    FROM int_reservation_events
)

SELECT * FROM final
