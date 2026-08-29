WITH club_members AS (
    SELECT * FROM {{ ref("int_club_members_enriched") }}
),

final AS (
    SELECT
        member_id,
        post_code,
        city,
        country,
        labels,
        roll,
        is_club_member,
        is_knltb_member,
        gender,
        current_type_of_membership,
        current_membership_start_date,
        inactive_type_of_membership,
        former_membership_start_date,
        active_products,
        active_product_date,
        inactive_products,
        inactive_products_date,
        additional_information,
        reasons_for_cancellation,
        reasons_for_cancellation_comment,
        club_app_login_date,
        services_current_year,
        singles_level,
        doubles_level,
        padel_level,
        ranking_singles,
        ranking_doubles,
        ranking_padel,
        choice_of_membership,
        volunteer_type,
        birth_date,
        member_since,
        age,
        age_group,
        membership_length_in_months
    FROM club_members
)

SELECT * FROM final
