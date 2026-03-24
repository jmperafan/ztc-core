with source as (
    select * from {{ source('ztc', 'club_members') }}
),

renamed as (
    select
        CLUBLIDNUMMER                       as member_id,
        GEBOORTEDATUM                       as birth_date,
        POSTCODE                            as post_code,
        WOONPLAATS                          as city,
        LAND                                as country,
        LABELS                              as labels,
        ROLLEN                              as roll,
        CLUBLID                             as is_club_member,
        BONDSLID                            as is_knltb_member,
        LID_SINDS                           as member_since,
        GESLACHT                            as gender,
        ACTIEVE_LIDMAATSCHAP_PEN            as current_type_of_membership,
        ACTIEVE_LIDMAATSCHAP_PEN_DATUM      as current_membership_start_date,
        INACTIEVE_LIDMAATSCHAP_PEN          as inactive_type_of_membership,
        INACTIEVE_LIDMAATSCHAP_PEN_DATUM    as former_membership_start_date,
        ACTIEVE_PRODUCT_EN                  as active_products,
        ACTIEVE_PRODUCT_EN_DATUM            as active_product_date,
        INACTIEVE_PRODUCT_EN                as inactive_products,
        INACTIEVE_PRODUCT_EN_DATUM          as inactive_products_date,
        EXTRA_INFORMATIE                    as additional_information,
        OPZEGREDEN                          as reasons_for_cancellation,
        OPZEGREDEN_OPMERKING                as reasons_for_cancellation_comment,
        CLUBAPP_LOGIN                       as club_app_login_date,
        DIENSTENPUNTEN_DIT_SEIZOEN          as services_current_year,
        TENNIS_SPEELSTERKTE_ENKEL           as singles_level,
        TENNIS_SPEELSTERKTE_DUBBEL          as doubles_level,
        PADEL_SPEELSTERKTE                  as padel_level,
        TENNIS_RATING_ENKEL                 as ranking_singles,
        TENNIS_RATING_DUBBEL                as ranking_doubles,
        PADEL_RATING                        as ranking_padel,
        KEUZE_LIDMAATSCHAP                  as choice_of_membership,
        VRIJWILLIGERS                       as volunteer_type
    from source
)

select * from renamed
