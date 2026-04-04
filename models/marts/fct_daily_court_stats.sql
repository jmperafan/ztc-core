{{
  config(
    materialized='incremental',
    unique_key='daily_court_key',
    incremental_strategy='delete+insert',
    on_schema_change='fail'
  )
}}

SELECT
    CONCAT(
        court_number::varchar, '_', reservation_date::varchar
    ) AS daily_court_key,
    court_number,
    reservation_date,
    COUNT_IF(reservation_type = 'Gereserveerd')                     AS booked_slots,
    COUNT_IF(reservation_type = 'Beschikbaar')                      AS available_slots,
    COUNT_IF(reservation_type IN ('Gereserveerd', 'Beschikbaar'))   AS total_playable_slots,
    SUM(
        CASE WHEN reservation_type = 'Gereserveerd'
             THEN duration_in_mins ELSE 0 END
    )                                                                AS booked_minutes,
    SUM(
        CASE WHEN reservation_type IN ('Gereserveerd', 'Beschikbaar')
             THEN duration_in_mins ELSE 0 END
    )                                                                AS available_minutes,
    ROUND(
        COUNT_IF(reservation_type = 'Gereserveerd') * 100.0
        / NULLIF(COUNT_IF(reservation_type IN ('Gereserveerd', 'Beschikbaar')), 0),
        2
    )                                                                AS utilization_pct

FROM {{ ref('fct_court_usage') }}
WHERE NOT is_winter_break

{% if is_incremental() %}
    -- On incremental runs, only process dates we haven't seen yet.
    -- delete+insert removes any existing rows for those dates before inserting,
    -- so late-arriving corrections within a day are handled cleanly.
    AND reservation_date > (SELECT MAX(reservation_date) FROM {{ this }})
{% endif %}

GROUP BY 1, 2, 3
