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
)

SELECT * FROM final
