WITH source AS (
    SELECT * FROM {{ ref('stg_weather_data') }}
),

-- The source omits UTC offset, so the local 02:00 hour repeats during DST fallback.
-- Keep one stable row per local reporting hour until ingestion provides an absolute timestamp.
ranked AS (
    SELECT
        *,
        HASH(*) AS _weather_row_hash
    FROM source
),

deduped AS (
    SELECT * EXCLUDE (_weather_row_hash)
    FROM ranked
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY datetime
        ORDER BY _weather_row_hash
    ) = 1
),

-- The tennis-playability flag is derived here rather than in fct_weather so
-- that int_hourly_weather_usage can consume it without depending on core.
final AS (
    SELECT
        *,
        {{ tennis_weather("temperature", "precipitation", "wind_speed") }} AS ideal_weather
    FROM deduped
)

SELECT * FROM final
