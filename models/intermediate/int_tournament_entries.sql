WITH

stg_tournament_entries AS (
    SELECT * FROM {{ ref('stg_tournament_entries') }}
),

dim_tournaments AS (
    SELECT * FROM {{ ref('dim_tournaments') }}
),

dim_members AS (
    SELECT * FROM {{ ref('dim_members') }}
),

final AS (
    SELECT
        e.entry_id,
        e.tournament_id,
        t.tournament_name,
        t.category AS tournament_category,
        t.season_year,
        e.registration_date,
        e.seed,
        e.entry_fee_paid,
        e.final_placement,
        e.final_placement = 'Champion' AS is_champion,
        e.member_id,
        m.gender,
        m.age_group,
        m.city
    FROM stg_tournament_entries AS e
    LEFT JOIN dim_tournaments AS t ON e.tournament_id = t.tournament_id
    LEFT JOIN dim_members AS m ON e.member_id = m.member_id::varchar
)

SELECT * FROM final
