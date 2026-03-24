with source as (
    select * from {{ ref('stg_weather_data') }}
),

final as (
    select
        datetime,
        temperature,
        thermal_sensation,
        humidity,
        precipitation,
        snow,
        wind_gust,
        wind_speed,
        solar_energy,
        {{ tennis_weather("temperature", "precipitation", "wind_speed") }} as ideal_weather
    from source
)

select * from final