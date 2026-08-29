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
        -- "seed" is the tournament seeding rank, not the SEED keyword.
        CAST(seed AS NUMBER(4, 0)) AS seed,  -- noqa: RF04
        entry_fee_paid,
        final_placement
    FROM source
)

SELECT * FROM renamed
