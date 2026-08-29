WITH

source AS (
    SELECT * FROM {{ source('ztc', 'sales_transactions') }}
),

renamed AS (
    SELECT
        transaction_id,
        member_id,
        product_id,
        transaction_date,
        CAST(quantity AS NUMBER(6, 0)) AS quantity,
        unit_price,
        discount_pct,
        total_amount
    FROM source
)

SELECT * FROM renamed
