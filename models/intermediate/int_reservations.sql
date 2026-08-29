-- Materialized as a table: three downstream models read this, so as a view
-- its dedup window function would be recomputed three times per run.
{{
  config(
    materialized='table'
  )
}}

WITH

stg_reservations AS (
    SELECT * FROM {{ ref('stg_reservations') }}
),

deduped AS (
    -- Resolve duplicate bookings from the source system, keeping one row per
    -- court/date/start_time. Post-rename equivalent of the dedup that used to
    -- live in stg_reservations; mirrors the pattern in int_club_members.
    SELECT *
    FROM stg_reservations
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY court_number, reservation_date, start_time
        ORDER BY reservation_date
    ) = 1
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['court_number', 'reservation_date', 'start_time']) }} AS reservation_id,  -- noqa: TMP,PRS,LT02,LT05
        reservation_date,
        start_time,
        end_time,
        CAST(CONCAT(reservation_date, ' ', start_time) AS TIMESTAMP) AS reservation_start,
        CAST(CONCAT(reservation_date, ' ', end_time) AS TIMESTAMP) AS reservation_end,
        duration_in_hours,
        court_number,
        player_1,
        player_2,
        player_3,
        player_4,
        member_id,
        reservation_type,
        event_description
    FROM deduped
)

SELECT * FROM final
