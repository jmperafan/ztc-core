with club_members as (
    select * from {{ ref("stg_club_members") }}
),

final as (
    select
        *,
        DATEDIFF('year', birth_date, CURRENT_DATE()) as age,
        {{ age_group("age") }} as age_group,
        DATEDIFF('month', member_since, CURRENT_DATE()) as membership_length_in_months
    from club_members
)

select * from final
