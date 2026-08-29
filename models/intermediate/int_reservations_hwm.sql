WITH

int_reservation_events AS (
    SELECT * FROM {{ ref('int_reservation_events') }}
),

fct_weather AS (
    SELECT * FROM {{ ref('fct_weather') }}
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

-- int_reservations_hwm is int_reservation_events plus the hourly weather
-- observation at each booking's date/hour. The member-enrichment logic lives
-- once, in int_reservation_events; here we only add the weather join.
final AS (
    SELECT
        e.reservation_id,
        e.reservation_date,
        e.court_number,
        e.start_time,
        e.end_time,
        e.duration_in_mins,
        e.day_of_week,
        e.day_of_week_name,
        e.start_hour,
        e.member_id,
        e.gender,
        e.age_group,
        e.city,
        e.current_type_of_membership,
        e.is_club_member,
        e.is_knltb_member,
        w.temperature,
        w.precipitation,
        w.wind_speed,
        w.ideal_weather
    FROM int_reservation_events AS e
    LEFT JOIN weather AS w
        ON
            e.reservation_date = w.weather_date
            AND e.start_hour = w.weather_hour
)

SELECT * FROM final
