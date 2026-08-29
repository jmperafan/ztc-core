-- Materialized as a table: three downstream models read this.
{{
  config(
    materialized='table'
  )
}}

WITH

stg_products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

deduped AS (
    SELECT *
    FROM stg_products
    QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) = 1
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
        category = 'Services' AS is_service,
        stock_quantity > 0 AS is_in_stock
    FROM deduped
)

SELECT * FROM final
