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

final AS (
    SELECT * EXCLUDE (_weather_row_hash)
    FROM ranked
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY datetime
        ORDER BY _weather_row_hash
    ) = 1
)

SELECT * FROM final
