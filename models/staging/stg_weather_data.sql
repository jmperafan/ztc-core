WITH source AS (
    SELECT * FROM {{ source('ztc', 'weather_data') }}
),

final AS (
    SELECT
        TRY_TO_TIMESTAMP_NTZ(datetime) AS datetime,
        temp AS temperature,
        feelslike AS thermal_sensation,
        dew,
        humidity,
        precip AS precipitation,
        -- A whole-percent probability; NUMBER(38,0) was the warehouse
        -- default, not a decision.
        CAST(precipprob AS NUMBER(3, 0)) AS precipitation_probability,
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
        -- UV index is a 0-11 integer scale; it arrived as FLOAT.
        CAST(uvindex AS NUMBER(2, 0)) AS uv_index,
        CAST(severerisk AS NUMBER(2, 0)) AS severe_risk,
        conditions,
        icon,
        stations
    FROM source
)

SELECT * FROM final
