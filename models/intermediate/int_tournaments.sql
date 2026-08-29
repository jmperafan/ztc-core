-- Materialized as a table: three downstream models read this.
{{
  config(
    materialized='table'
  )
}}

WITH

stg_tournaments AS (
    SELECT * FROM {{ ref('stg_tournaments') }}
),

deduped AS (
    SELECT *
    FROM stg_tournaments
    QUALIFY ROW_NUMBER() OVER (PARTITION BY tournament_id ORDER BY start_date) = 1
),

final AS (
    SELECT
        tournament_id,
        tournament_name,
        start_date,
        end_date,
        DATEDIFF('day', start_date, end_date) + 1 AS duration_days,
        DATEDIFF('day', start_date, end_date) > 0 AS is_multi_day,
        category,
        entry_fee,
        max_participants,
        season_year
    FROM deduped
)

SELECT * FROM final
