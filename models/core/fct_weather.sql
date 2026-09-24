{{
  config(
    materialized='incremental',
    incremental_strategy='append',
    on_schema_change='fail'
  )
}}

WITH source AS (
    SELECT * FROM {{ ref('int_weather_data') }}
),

final AS (
    SELECT
        datetime,
        temperature,
        thermal_sensation,
        humidity,
        precipitation,
        snow,
        wind_gust,
        wind_speed,
        solar_energy,
        ideal_weather
    FROM source

    {% if is_incremental() %}
        -- Append has no unique_key and does not de-duplicate, so the filter
        -- must be strictly greater than the current maximum. Weather
        -- observations are immutable once recorded, which is what makes
        -- insert-only loading safe here.
        WHERE datetime > (SELECT MAX(datetime) FROM {{ this }})  -- noqa: RF02
    {% endif %}
)

SELECT * FROM final
