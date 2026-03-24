WITH source AS (
    SELECT * FROM {{ source('ztc', 'club_members') }}
),

renamed AS (
    SELECT
        clublidnummer AS member_id,
        postcode AS post_code,
        woonplaats AS city,
        land AS country,
        labels,
        rollen AS roll,
        clublid AS is_club_member,
        bondslid AS is_knltb_member,
        geslacht AS gender,
        actieve_lidmaatschap_pen AS current_type_of_membership,
        actieve_lidmaatschap_pen_datum AS current_membership_start_date,
        inactieve_lidmaatschap_pen AS inactive_type_of_membership,
        inactieve_lidmaatschap_pen_datum AS former_membership_start_date,
        actieve_product_en AS active_products,
        actieve_product_en_datum AS active_product_date,
        inactieve_product_en AS inactive_products,
        inactieve_product_en_datum AS inactive_products_date,
        extra_informatie AS additional_information,
        opzegreden AS reasons_for_cancellation,
        opzegreden_opmerking AS reasons_for_cancellation_comment,
        clubapp_login AS club_app_login_date,
        dienstenpunten_dit_seizoen AS services_current_year,
        tennis_speelsterkte_enkel AS singles_level,
        tennis_speelsterkte_dubbel AS doubles_level,
        padel_speelsterkte AS padel_level,
        tennis_rating_enkel AS ranking_singles,
        tennis_rating_dubbel AS ranking_doubles,
        padel_rating AS ranking_padel,
        keuze_lidmaatschap AS choice_of_membership,
        vrijwilligers AS volunteer_type,
        TO_DATE(geboortedatum, 'DD/MM/YYYY') AS birth_date,
        TO_DATE(lid_sinds, 'DD/MM/YYYY') AS member_since
    FROM source
)

SELECT * FROM renamed
