-- High Watermark incremental pattern.
--
-- Compare with fct_reservation_events (microbatch — dbt manages the window
-- automatically) to see two different approaches to incremental loading.
--
-- The HWM pattern stores the exact upper bound used on each run in a central
-- watermark table. This means every processing window is mutually exclusive
-- and collectively exhaustive — unlike MAX(col) FROM {{ this }}, the upper
-- bound is captured before the model runs, not derived from the target table.

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

WITH reservations AS (
    SELECT
        reservation_id,
        reservation_date,
        court_number,
        start_time,
        end_time,
        duration_in_mins,
        DAYOFWEEK(reservation_date) AS day_of_week,
        DAYNAME(reservation_date) AS day_of_week_name,
        HOUR(start_time) AS start_hour
    FROM {{ ref('fct_reservations') }}
    WHERE
        reservation_type = 'Gereserveerd'

        {% if is_incremental() %}
            AND reservation_date BETWEEN ({{ get_previous_hwm(ref('fct_reservations')) }})
            AND ({{ get_current_hwm(ref('fct_reservations')) }})
        {% endif %}
),

member_bridge AS (
    SELECT
        reservation_id,
        member_id
    FROM {{ ref('bridge_member_reservations') }}
),

member_profiles AS (
    SELECT
        member_id,
        gender,
        age_group,
        city,
        current_type_of_membership,
        is_club_member,
        is_knltb_member
    FROM {{ ref('dim_members') }}
),

weather AS (
    SELECT
        DATE(datetime) AS weather_date,
        HOUR(datetime) AS weather_hour,
        temperature,
        precipitation,
        wind_speed,
        ideal_weather
    FROM {{ ref('fct_weather') }}
),

final AS (
    SELECT
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
    FROM reservations AS r
    LEFT JOIN member_bridge AS b ON r.reservation_id = b.reservation_id
    LEFT JOIN member_profiles AS p ON b.member_id = p.member_id
    LEFT JOIN weather AS w
        ON
            r.reservation_date = w.weather_date
            AND r.start_hour = w.weather_hour
)

SELECT * FROM final
