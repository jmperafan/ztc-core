WITH source AS (
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
        CAST(CONCAT(reservation_date, ' ', start_time) AS TIMESTAMP) AS reservation_start,
        CAST(CONCAT(reservation_date, ' ', end_time) AS TIMESTAMP) AS reservation_end,
        uren AS duration_in_hours,
        CAST(RIGHT(banen, 1) AS INTEGER) AS court_number,
        inschrijver_persoon1 AS player_1,
        persoon2 AS player_2,
        persoon3 AS player_3,
        persoon4 AS player_4,
        clublidnummer AS member_id,
        type AS reservation_type,
        beschrijving AS event_description
    FROM source
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['court_number', 'reservation_date', 'start_time']) }} AS reservation_id,
        reservation_date,
        start_time,
        end_time,
        reservation_start,
        reservation_end,
        duration_in_hours,
        court_number,
        player_1,
        player_2,
        player_3,
        player_4,
        member_id,
        reservation_type,
        event_description
    FROM renamed
)

SELECT * FROM final
