WITH

stg_coaches AS (
    SELECT * FROM {{ ref('stg_coaches') }}
),

deduped AS (
    -- Defensive dedup on the natural key, mirroring int_club_members.
    SELECT *
    FROM stg_coaches
    QUALIFY ROW_NUMBER() OVER (PARTITION BY coach_id ORDER BY hire_date) = 1
),

final AS (
    SELECT
        coach_id,
        first_name,
        last_name,
        first_name || ' ' || last_name AS full_name,
        email,
        phone,
        hire_date,
        DATEDIFF('year', hire_date, CURRENT_DATE()) AS years_at_club,
        specialty,
        certification_level,
        hourly_rate,
        is_active
    FROM deduped
)

SELECT * FROM final
