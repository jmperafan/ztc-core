WITH equipment_rentals AS (
    SELECT * FROM {{ ref('int_equipment_rentals') }}
),

final AS (
    SELECT
        rental_id,
        member_id,
        gender,
        age_group,
        city,
        product_id,
        product_name,
        product_category,
        rental_date,
        return_date,
        rental_duration_days,
        rental_fee,
        late_fee,
        total_fee,
        was_returned
    FROM equipment_rentals
)

SELECT * FROM final
