with

reservations as (
    select * from {{ ref("bridge_member_reservations") }}
),

members as (
    select * from {{ ref("stg_club_members") }}
),

unioned as (
    select {{ clean_text("player_name") }} as player_name from reservations
    union
    select {{ clean_text("player_name") }} as player_name from members
),

cartesian_product as (
    select
        x.player_name as player_name_1,
        y.player_name as player_name_2,
        JAROWINKLER_SIMILARITY(player_name_1, player_name_2) as jaro_similarity
    from unioned as x
    full outer join unioned as y
        on x.player_name != y.player_name
    where jaro_similarity >= 70
),

remove_duplicates as (
    select
        case
            when player_name_1 < player_name_2 then player_name_1 || '|' || player_name_2
            else player_name_2 || '|' || player_name_1
        end as concatenated_columns,
        min(jaro_similarity) as jaro_similarity
    from cartesian_product
    group by concatenated_columns
)

select * from remove_duplicates
