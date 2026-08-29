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
        CAST(TRY_TO_NUMBER(RIGHT(court_id, 1)) AS NUMBER(2, 0)) AS court_number,
        lesson_date,
        start_time,
        CAST(duration_minutes AS NUMBER(6, 0)) AS duration_minutes,
        lesson_type,
        level AS skill_level,
        price,
        status,
        created_at
    FROM source
)

SELECT * FROM renamed
