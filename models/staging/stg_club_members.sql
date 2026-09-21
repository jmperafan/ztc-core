WITH source AS (
    SELECT * FROM {{ source('ztc', 'club_members') }}
),

final AS (
    SELECT
        clublidnummer AS member_id,
        postcode AS post_code,
        {{ initcap_dutch('woonplaats') }} AS city,
        {{ initcap_dutch('land') }} AS country,
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
        -- Service points are awarded whole; FLOAT invited false precision.
        CAST(dienstenpunten_dit_seizoen AS NUMBER(3, 0)) AS services_current_year,
        -- Speelsterkte is the KNLTB 1-9 playing-strength grade, an integer.
        -- It arrives as FLOAT and was passed through uncast.
        CAST(tennis_speelsterkte_enkel AS NUMBER(1, 0)) AS singles_level,
        CAST(tennis_speelsterkte_dubbel AS NUMBER(1, 0)) AS doubles_level,
        CAST(padel_speelsterkte AS NUMBER(1, 0)) AS padel_level,
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
