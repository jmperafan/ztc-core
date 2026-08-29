WITH

source AS (
    SELECT * FROM {{ source('ztc', 'tournaments') }}
),

renamed AS (
    SELECT
        tournament_id,
        name AS tournament_name,
        start_date,
        end_date,
        category,
        entry_fee,
        max_participants,
        season_year
    FROM source
)

SELECT * FROM renamed
