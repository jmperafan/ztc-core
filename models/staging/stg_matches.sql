WITH

source AS (
    SELECT * FROM {{ source('ztc', 'matches') }}
),

renamed AS (
    SELECT
        match_id,
        tournament_id,
        player1_member_id,
        player2_member_id,
        court_id,
        TRY_TO_NUMBER(RIGHT(court_id, 1)) AS court_number,
        match_date,
        start_time,
        duration_minutes,
        winner_member_id,
        score,
        round_name
    FROM source
)

SELECT * FROM renamed
