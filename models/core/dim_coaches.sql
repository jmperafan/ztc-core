WITH coaches AS (
    SELECT *
),

final AS (
    SELECT
        coach_id,
        first_name,
        last_name,
        full_name,
        email,
        phone,
        hire_date,
        years_at_club,
        specialty,
        certification_level,
        hourly_rate,
        is_active
    FROM coaches
)

SELECT * FROM final
