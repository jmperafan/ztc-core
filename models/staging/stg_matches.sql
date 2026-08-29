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
        CAST(TRY_TO_NUMBER(RIGHT(court_id, 1)) AS NUMBER(2, 0)) AS court_number,
        match_date,
        start_time,
        CAST(duration_minutes AS NUMBER(6, 0)) AS duration_minutes,
        winner_member_id,
        score,
        round_name
    FROM source
)

SELECT * FROM renamed
