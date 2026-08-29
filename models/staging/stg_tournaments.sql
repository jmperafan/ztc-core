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
        CAST(max_participants AS NUMBER(6, 0)) AS max_participants,
        CAST(season_year AS NUMBER(4, 0)) AS season_year
    FROM source
)

SELECT * FROM renamed
