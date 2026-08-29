WITH

stg_lessons AS (
    SELECT * FROM {{ ref('stg_lessons') }}
),

dim_coaches AS (
    SELECT * FROM {{ ref('dim_coaches') }}
),

dim_members AS (
    SELECT * FROM {{ ref('dim_members') }}
),

final AS (
    SELECT
        l.lesson_id,
        l.lesson_date,
        l.start_time,
        HOUR(l.start_time) AS start_hour,
        DAYOFWEEK(l.lesson_date) AS day_of_week,
        DAYNAME(l.lesson_date) AS day_of_week_name,
        DAYOFWEEKISO(l.lesson_date) >= 6 AS is_weekend,
        l.duration_minutes,
        l.lesson_type,
        l.skill_level,
        l.price,
        l.status,
        l.status = 'Cancelled' AS is_cancelled,
        l.court_id,
        l.court_number,
        l.coach_id,
        c.full_name AS coach_name,
        c.specialty AS coach_specialty,
        l.member_id,
        m.gender,
        m.age_group,
        m.city,
        m.current_type_of_membership,
        l.created_at
    FROM stg_lessons AS l
    LEFT JOIN dim_coaches AS c ON l.coach_id = c.coach_id
    LEFT JOIN dim_members AS m ON l.member_id = m.member_id::varchar
)

SELECT * FROM final
