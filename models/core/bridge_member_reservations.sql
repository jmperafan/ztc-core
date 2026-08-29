WITH member_reservations AS (
    SELECT * FROM {{ ref('int_member_reservations') }}
),

final AS (
    SELECT
        reservation_id,
        member_id
    FROM member_reservations
)

SELECT * FROM final
