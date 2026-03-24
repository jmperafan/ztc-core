with source as (
    select * from {{ source('ztc', 'weather_data') }}
),

renamed as (
    select
        DATETIME,
        TEMP                as temperature,
        FEELSLIKE           as thermal_sensation,
        DEW,
        HUMIDITY,
        PRECIP              as precipitation,
        PRECIPPROB          as precipitation_probability,
        PRECIPTYPE          as precipitation_type,
        SNOW,
        SNOWDEPTH           as snow_depth,
        WINDGUST            as wind_gust,
        WINDSPEED           as wind_speed,
        WINDDIR             as wind_direction,
        SEALEVELPRESSURE    as sea_level_pressure,
        CLOUDCOVER          as cloud_cover,
        VISIBILITY,
        SOLARRADIATION      as solar_radiation,
        SOLARENERGY         as solar_energy,
        UVINDEX             as uv_index,
        SEVERERISK          as severe_risk,
        CONDITIONS,
        ICON,
        STATIONS
    from source
)

select * from renamed
