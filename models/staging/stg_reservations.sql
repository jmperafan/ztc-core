WITH

source AS (
    SELECT * FROM {{ source('ztc', 'court_usage') }}
),

renamed AS (
    SELECT
        CAST(startdatum AS DATE) AS reservation_date,
        CASE
            WHEN begintijd LIKE '____-__-__%'
                THEN CAST(TO_TIMESTAMP(begintijd, 'YYYY-MM-DD HH24:MI:SS') AS TIME)
            ELSE TO_TIME(begintijd)
        END AS start_time,
        CASE
            WHEN eindtijd LIKE '____-__-__%'
                THEN CAST(TO_TIMESTAMP(eindtijd, 'YYYY-MM-DD HH24:MI:SS') AS TIME)
            ELSE TO_TIME(eindtijd)
        END AS end_time,
        uren AS duration_in_hours,
        CAST(RIGHT(banen, 1) AS NUMBER(2, 0)) AS court_number,
        inschrijver_persoon1 AS player_1,
        persoon2 AS player_2,
        persoon3 AS player_3,
        persoon4 AS player_4,
        CAST(clublidnummer AS NUMBER) AS member_id,
        type AS reservation_type,
        beschrijving AS event_description
    FROM source
)

SELECT * FROM renamed
