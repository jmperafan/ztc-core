WITH source AS (
    SELECT * FROM
),

final AS (
    SELECT
        clublidnummer AS member_id,
        postcode AS post_code,
        woonplaats AS city,
        land AS country,
        labels,
        rollen AS roll,
        {{ dutch_bool('clublid') }} AS is_club_member,
        {{ dutch_bool('bondslid') }} AS is_knltb_member,
        geslacht AS gender,
        actieve_lidmaatschap_pen AS current_type_of_membership,
        TRY_TO_DATE(actieve_lidmaatschap_pen_datum, 'DD/MM/YYYY') AS current_membership_start_date,
        inactieve_lidmaatschap_pen AS inactive_type_of_membership,
        TRY_TO_DATE(inactieve_lidmaatschap_pen_datum, 'DD/MM/YYYY') AS former_membership_start_date,
        actieve_product_en AS active_products,
        TRY_TO_DATE(actieve_product_en_datum, 'DD/MM/YYYY') AS active_product_date,
        inactieve_product_en AS inactive_products,
        TRY_TO_DATE(inactieve_product_en_datum, 'DD/MM/YYYY') AS inactive_products_date,
        CAST(extra_informatie AS VARCHAR) AS additional_information,
        opzegreden AS reasons_for_cancellation,
        opzegreden_opmerking AS reasons_for_cancellation_comment,
        TRY_TO_DATE(clubapp_login, 'DD/MM/YYYY') AS club_app_login_date,
        CAST(dienstenpunten_dit_seizoen AS FLOAT) AS services_current_year,
        tennis_speelsterkte_enkel AS singles_level,
        tennis_speelsterkte_dubbel AS doubles_level,
        padel_speelsterkte AS padel_level,
        TRY_CAST(tennis_rating_enkel AS FLOAT) AS ranking_singles,
        TRY_CAST(tennis_rating_dubbel AS FLOAT) AS ranking_doubles,
        TRY_CAST(padel_rating AS FLOAT) AS ranking_padel,
        keuze_lidmaatschap AS choice_of_membership,
        vrijwilligers AS volunteer_type,
        TO_DATE(geboortedatum, 'DD/MM/YYYY') AS birth_date,
        TO_DATE(lid_sinds, 'DD/MM/YYYY') AS member_since
    FROM source
)

SELECT * FROM final
