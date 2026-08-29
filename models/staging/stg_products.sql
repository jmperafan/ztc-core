WITH

source AS (
    SELECT * FROM {{ source('ztc', 'products') }}
),

renamed AS (
    SELECT
        product_id,
        name AS product_name,
        category,
        brand,
        unit_price,
        is_rentable,
        rental_fee,
        stock_quantity
    FROM source
)

SELECT * FROM renamed
