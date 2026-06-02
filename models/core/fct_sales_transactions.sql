WITH sales_transactions AS (
    SELECT * FROM {{ ref('int_sales_transactions') }}
),

final AS (
    SELECT
        transaction_id,
        transaction_date,
        member_id,
        gender,
        age_group,
        city,
        product_id,
        product_name,
        product_category,
        product_brand,
        quantity,
        unit_price,
        discount_pct,
        gross_amount,
        net_amount
    FROM sales_transactions
)

SELECT * FROM final
