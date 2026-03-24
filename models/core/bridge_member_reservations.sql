with

reservations as (
    select
        reservation_id,
        member_id
    from {{ ref("stg_reservations") }}
    where member_id is not null
),

members as (
    select member_id from {{ ref('dim_members') }}
),

final as (
    select
        r.reservation_id,
        r.member_id
    from reservations r
    inner join members m on r.member_id = m.member_id
)

select * from final
