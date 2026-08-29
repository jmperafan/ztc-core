WITH

int_reservations AS (
    SELECT * FROM {{ ref('int_reservations') }}
),

club_members AS (
    SELECT * FROM {{ ref('int_club_members_enriched') }}
),

reservations AS (
    SELECT
        reservation_id,
        member_id
    FROM int_reservations
    WHERE member_id IS NOT NULL
),

members AS (
    SELECT member_id
    FROM club_members
),

final AS (
    -- Explicit casts pin output types to the contract bridge_member_reservations
    -- declares. stg_reservations has no contract, so without these the
    -- upstream's inferred types (REAL/NUMBER) leak through and break contract
    -- validation. The inner join is what makes this a bridge: only reservations
    -- whose member_id resolves to a known member survive.
    SELECT
        CAST(r.reservation_id AS VARCHAR) AS reservation_id,
        CAST(r.member_id AS NUMBER(38, 0)) AS member_id
    FROM reservations AS r
    INNER JOIN members AS m ON r.member_id = m.member_id
)

SELECT * FROM final
