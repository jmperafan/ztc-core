WITH matches AS (
    SELECT * FROM {{ ref('int_matches') }}
),

final AS (
    SELECT
        match_id,
        tournament_id,
        tournament_name,
        tournament_category,
        season_year,
        round_name,
        match_date,
        start_time,
        duration_minutes,
        court_id,
        court_number,
        player1_member_id,
        player2_member_id,
        winner_member_id,
        winner_is_player1,
        score,
        sets_played
    FROM matches
)

SELECT * FROM final
