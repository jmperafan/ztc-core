with source as (
    select * from {{ source('ztc', 'court_usage') }}
),

renamed as (
    select
        cast(STARTDATUM as date)                         as reservation_date,
        TO_TIME(TO_TIMESTAMP(BEGINTIJD, 'YYYY-MM-DD HH24:MI:SS')) as start_time,
        TO_TIME(TO_TIMESTAMP(EINDTIJD, 'YYYY-MM-DD HH24:MI:SS'))  as end_time,
        cast(concat(reservation_date, ' ', start_time) as timestamp) as reservation_start,
        cast(concat(reservation_date, ' ', end_time) as timestamp)   as reservation_end,
        UREN                                             as duration_in_hours,
        cast(right(BANEN, 1) as integer)                as court_number,
        INSCHRIJVER_PERSOON1                             as player_1,
        PERSOON2                                         as player_2,
        PERSOON3                                         as player_3,
        PERSOON4                                         as player_4,
        CLUBLIDNUMMER                                    as member_id,
        TYPE                                             as reservation_type,
        BESCHRIJVING                                     as event_description
    from source
    order by court_number, reservation_start
)

select
    row_number() over (order by court_number, reservation_start) as reservation_id,
    *
from renamed
