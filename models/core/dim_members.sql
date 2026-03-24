WITH club_members AS (
    SELECT * FROM {{ ref("stg_club_members") }}
),

final AS (
    SELECT
        *,
        DATEDIFF('year', birth_date, CURRENT_DATE()) AS age,
        {{ age_group("age") }} AS age_group,
        DATEDIFF('month', member_since, CURRENT_DATE()) AS membership_length_in_months
    FROM club_members
)

SELECT * FROM final
