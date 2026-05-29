WITH source AS (
    SELECT * FROM
),

final AS (
    SELECT
        TRY_TO_TIMESTAMP_NTZ(datetime) AS datetime,
        temp AS temperature,
        feelslike AS thermal_sensation,
        dew,
        humidity,
        precip AS precipitation,
        precipprob AS precipitation_probability,
        preciptype AS precipitation_type,
        snow,
        snowdepth AS snow_depth,
        windgust AS wind_gust,
        windspeed AS wind_speed,
        winddir AS wind_direction,
        sealevelpressure AS sea_level_pressure,
        cloudcover AS cloud_cover,
        visibility,
        solarradiation AS solar_radiation,
        solarenergy AS solar_energy,
        uvindex AS uv_index,
        severerisk AS severe_risk,
        conditions,
        icon,
        stations
    FROM source
)

SELECT * FROM final
