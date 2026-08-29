WITH

source AS (
    SELECT * FROM {{ source('ztc', 'lessons') }}
),

renamed AS (
    SELECT
        lesson_id,
        member_id,
        coach_id,
        court_id,
        TRY_TO_NUMBER(RIGHT(court_id, 1)) AS court_number,
        lesson_date,
        start_time,
        duration_minutes,
        lesson_type,
        level AS skill_level,
        price,
        status,
        created_at
    FROM source
)

SELECT * FROM renamed
