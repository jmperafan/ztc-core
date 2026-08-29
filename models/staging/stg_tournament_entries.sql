WITH

source AS (
    SELECT * FROM {{ source('ztc', 'tournament_entries') }}
),

renamed AS (
    SELECT
        entry_id,
        tournament_id,
        member_id,
        registration_date,
        seed,
        entry_fee_paid,
        final_placement
    FROM source
)

SELECT * FROM renamed
