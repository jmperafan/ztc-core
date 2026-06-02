WITH tournaments AS (
    SELECT * FROM {{ ref('int_tournaments') }}
),

final AS (
    SELECT
        tournament_id,
        tournament_name,
        start_date,
        end_date,
        duration_days,
        is_multi_day,
        category,
        entry_fee,
        max_participants,
        season_year
    FROM tournaments
)

SELECT * FROM final
