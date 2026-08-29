WITH lessons AS (
    SELECT * FROM {{ ref('int_lessons') }}
),

final AS (
    SELECT
        lesson_id,
        lesson_date,
        start_time,
        start_hour,
        day_of_week,
        day_of_week_name,
        is_weekend,
        duration_minutes,
        lesson_type,
        skill_level,
        price,
        status,
        is_cancelled,
        court_id,
        court_number,
        coach_id,
        coach_name,
        coach_specialty,
        member_id,
        gender,
        age_group,
        city,
        current_type_of_membership,
        created_at
    FROM lessons
)

SELECT * FROM final
