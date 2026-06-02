{{
  config(
    materialized='incremental',
    unique_key=['reservation_date', 'start_hour', 'court_number'],
    incremental_strategy='merge',
    on_schema_change='fail'
  )
}}

WITH

int_hourly_weather_usage AS (
    SELECT * FROM {{ ref('int_hourly_weather_usage') }}
),

final AS (
    SELECT
        reservation_date,
        start_hour,
        court_number,
        booked_slots,
        available_slots,
        utilization_pct,
        temperature,
        precipitation,
        wind_speed,
        ideal_weather
    FROM int_hourly_weather_usage

    {% if is_incremental() %}
        WHERE reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})  -- noqa: RF02
    {% endif %}
)

SELECT * FROM final
