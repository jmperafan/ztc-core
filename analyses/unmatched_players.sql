with reservations as (
    select * from {{ ref("bridge_member_reservations") }}
),

unmatched as (
    select
        player_name,
        count(*) as reservations
    from reservations
    where knltb_number is null
    and player_name not like '%@%'
    group by player_name
)

select * from unmatched