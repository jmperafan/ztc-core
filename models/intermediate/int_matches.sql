WITH

stg_matches AS (
    SELECT * FROM {{ ref('stg_matches') }}
),

int_tournaments AS (
    SELECT * FROM {{ ref('int_tournaments') }}
),

final AS (
    SELECT
        m.match_id,
        m.tournament_id,
        t.tournament_name,
        t.category AS tournament_category,
        t.season_year,
        m.round_name,
        m.match_date,
        m.start_time,
        m.duration_minutes,
        m.court_id,
        m.court_number,
        m.player1_member_id,
        m.player2_member_id,
        m.winner_member_id,
        m.winner_member_id = m.player1_member_id AS winner_is_player1,
        m.score,
        REGEXP_COUNT(m.score, ',') + 1 AS sets_played
    FROM stg_matches AS m
    LEFT JOIN int_tournaments AS t ON m.tournament_id = t.tournament_id
)

SELECT * FROM final
