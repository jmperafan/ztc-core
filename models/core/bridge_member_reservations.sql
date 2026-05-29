WITH

stg_reservations AS (
    SELECT * 
),

dim_members AS (
    SELECT * FROM {{ ref('dim_members') }}
),

reservations AS (
    SELECT
        reservation_id,
        member_id
    FROM stg_reservations
    WHERE member_id IS NOT NULL
),

members AS (
    SELECT member_id
    FROM dim_members
),

final AS (
    -- Explicit casts pin output types to the contract declared in _models.yml.
    -- stg_reservations has no contract, so without these the upstream's
    -- inferred types (REAL/NUMBER) leak through and break contract validation.
    SELECT
        CAST(r.reservation_id AS VARCHAR) AS reservation_id,
        CAST(r.member_id AS NUMBER) AS member_id
    FROM reservations AS r
    INNER JOIN members AS m ON r.member_id = m.member_id
)

SELECT * FROM final
