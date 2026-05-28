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
    SELECT * FROM int_reservation_events
)

SELECT * FROM final
