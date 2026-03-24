WITH source AS (
    SELECT * FROM {{ ref('stg_weather_data') }}
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
        {{ tennis_weather("temperature", "precipitation", "wind_speed") }} AS ideal_weather
    FROM source
)

SELECT * FROM final
