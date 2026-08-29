WITH

stg_equipment_rentals AS (
    SELECT * FROM {{ ref('stg_equipment_rentals') }}
),

dim_products AS (
    SELECT * FROM {{ ref('dim_products') }}
),

dim_members AS (
    SELECT * FROM {{ ref('dim_members') }}
),

final AS (
    SELECT
        r.rental_id,
        r.member_id,
        m.gender,
        m.age_group,
        m.city,
        r.product_id,
        p.product_name,
        p.category AS product_category,
        r.rental_date,
        r.return_date,
        DATEDIFF('day', r.rental_date, r.return_date) AS rental_duration_days,
        r.rental_fee,
        r.late_fee,
        ROUND(r.rental_fee + r.late_fee, 2) AS total_fee,
        r.was_returned
    FROM stg_equipment_rentals AS r
    LEFT JOIN dim_products AS p ON r.product_id = p.product_id
    LEFT JOIN dim_members AS m ON r.member_id = m.member_id::varchar
)

SELECT * FROM final
