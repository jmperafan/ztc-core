WITH

int_court_slots AS (
    SELECT * FROM {{ ref('int_court_slots') }}
),

fct_weather AS (
    SELECT * FROM {{ ref('fct_weather') }}
),

hourly_usage AS (
    SELECT
        reservation_date,
        HOUR(start_time) AS start_hour,
        court_number,
        COUNT_IF(reservation_type = 'Gereserveerd') AS booked_slots,
        COUNT_IF(reservation_type = 'Beschikbaar') AS available_slots,
        ROUND(
            COUNT_IF(reservation_type = 'Gereserveerd') * 100.0
            / NULLIF(COUNT_IF(reservation_type IN ('Gereserveerd', 'Beschikbaar')), 0),
            2
        ) AS utilization_pct
    FROM int_court_slots
    WHERE
        NOT is_winter_break
        AND reservation_type != 'Gesloten'
    GROUP BY 1, 2, 3
),

weather AS (
    SELECT
        DATE(datetime) AS weather_date,
        HOUR(datetime) AS weather_hour,
        temperature,
        precipitation,
        wind_speed,
        ideal_weather
    FROM fct_weather
),

final AS (
    SELECT
        u.reservation_date,
        u.start_hour,
        u.court_number,
        u.booked_slots,
        u.available_slots,
        u.utilization_pct,
        w.temperature,
        w.precipitation,
        w.wind_speed,
        w.ideal_weather
    FROM hourly_usage AS u
    LEFT JOIN weather AS w
        ON
            u.reservation_date = w.weather_date
            AND u.start_hour = w.weather_hour
)

SELECT * FROM final
