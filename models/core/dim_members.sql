WITH club_members AS (
    SELECT * FROM {{ ref("int_club_members") }}
),

final AS (
    SELECT
        *,
        CAST(DATEDIFF('year', birth_date, CURRENT_DATE()) AS NUMBER(38,0)) AS age,
        CAST({{ age_group("age") }} AS NUMBER(38,0)) AS age_group,
        CAST(DATEDIFF('month', member_since, CURRENT_DATE()) AS NUMBER(38,0)) AS membership_length_in_months
    FROM club_members
)

SELECT * FROM final
