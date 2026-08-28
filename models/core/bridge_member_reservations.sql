WITH

reservations AS (
    SELECT
        reservation_id,
        member_id
    FROM {{ ref("stg_reservations") }}
    WHERE member_id IS NOT NULL
),

members AS (
    SELECT member_id FROM {{ ref('dim_members') }}
),

final AS (
    SELECT
        r.reservation_id,
        CAST(r.member_id AS NUMBER(38,0)) AS member_id
    FROM reservations AS r
    INNER JOIN members AS m ON r.member_id = m.member_id
)

SELECT * FROM final
