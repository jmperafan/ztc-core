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
    on_schema_change='fail',
    pre_hook="{{ set_job_param() }}",
    post_hook="{{ update_job_param(success=true) }}",
    meta={'hwm_field': 'reservation_date', 'hwm_source_model': 'fct_reservations'}
  )
}}

{#-
  Bind the HWM source ref at the top so Fusion's static analysis sees it
  as a dependency. A bare ref() inside an is_incremental() conditional
  block isn't always picked up by dbt's dependency inference.
-#}
{% set _fct_reservations = ref('fct_reservations') %}

WITH

int_reservations_hwm AS (
    SELECT * FROM {{ ref('int_reservations_hwm') }}
),

final AS (
    SELECT * FROM int_reservations_hwm

    {% if is_incremental() %}
        WHERE
            reservation_date BETWEEN ({{ get_previous_hwm(_fct_reservations) }})
            AND ({{ get_current_hwm(_fct_reservations) }})
    {% endif %}
)

SELECT * FROM final
