WITH tournament_entries AS (
    SELECT * FROM {{ ref('int_tournament_entries') }}
),

final AS (
    SELECT
        entry_id,
        tournament_id,
        tournament_name,
        tournament_category,
        season_year,
        registration_date,
        seed,
        entry_fee_paid,
        final_placement,
        is_champion,
        member_id,
        gender,
        age_group,
        city
    FROM tournament_entries
)

SELECT * FROM final
