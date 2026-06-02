{{
  config(
    materialized='incremental',
    unique_key='daily_court_key',
    incremental_strategy='delete+insert',
    on_schema_change='fail'
  )
}}

WITH

int_daily_court_stats AS (
    SELECT * FROM {{ ref('int_daily_court_stats') }}
),

final AS (
    SELECT
        daily_court_key,
        court_number,
        reservation_date,
        booked_slots,
        available_slots,
        total_playable_slots,
        booked_minutes,
        available_minutes,
        utilization_pct
    FROM int_daily_court_stats

    {% if is_incremental() %}
        WHERE reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})  -- noqa: RF02
    {% endif %}
)

SELECT * FROM final
