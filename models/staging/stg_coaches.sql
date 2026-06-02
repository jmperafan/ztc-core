WITH

source AS (
    SELECT * FROM {{ source('ztc', 'coaches') }}
),

renamed AS (
    SELECT
        coach_id,
        first_name,
        last_name,
        email,
        phone,
        hire_date,
        specialty,
        certification_level,
        hourly_rate,
        is_active
    FROM source
)

SELECT * FROM renamed
