WITH

stg_tournament_entries AS (
    SELECT * FROM {{ ref('stg_tournament_entries') }}
),

int_tournaments AS (
    SELECT * FROM {{ ref('int_tournaments') }}
),

int_club_members_enriched AS (
    SELECT * FROM {{ ref('int_club_members_enriched') }}
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
    LEFT JOIN int_tournaments AS t ON e.tournament_id = t.tournament_id
    LEFT JOIN int_club_members_enriched AS m ON e.member_id = m.member_id::varchar
)

SELECT * FROM final
