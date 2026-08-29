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
        CAST(stock_quantity AS NUMBER(9, 0)) AS stock_quantity
    FROM source
)

SELECT * FROM renamed
