WITH source AS (
    SELECT * FROM {{ ref('stg_weather_data') }}
),

-- Deduplicate on datetime, keeping the first record per hour.
-- Duplicate datetime values can appear in the source (e.g. overlapping data loads).
final AS (
    SELECT * FROM source
    QUALIFY ROW_NUMBER() OVER (PARTITION BY datetime ORDER BY datetime) = 1
)

SELECT * FROM final
