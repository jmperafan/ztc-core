WITH products AS (
    SELECT * FROM {{ ref('int_products') }}
),

final AS (
    SELECT
        product_id,
        product_name,
        category,
        brand,
        unit_price,
        is_rentable,
        rental_fee,
        stock_quantity,
        is_service,
        is_in_stock
    FROM products
)

SELECT * FROM final
