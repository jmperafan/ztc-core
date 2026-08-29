WITH

stg_sales_transactions AS (
    SELECT * FROM {{ ref('stg_sales_transactions') }}
),

int_products AS (
    SELECT * FROM {{ ref('int_products') }}
),

int_club_members_enriched AS (
    SELECT * FROM {{ ref('int_club_members_enriched') }}
),

final AS (
    SELECT
        s.transaction_id,
        s.transaction_date,
        s.member_id,
        m.gender,
        m.age_group,
        m.city,
        s.product_id,
        p.product_name,
        p.category AS product_category,
        p.brand AS product_brand,
        s.quantity,
        s.unit_price,
        s.discount_pct,
        ROUND(s.quantity * s.unit_price, 2) AS gross_amount,
        s.total_amount AS net_amount
    FROM stg_sales_transactions AS s
    LEFT JOIN int_products AS p ON s.product_id = p.product_id
    LEFT JOIN int_club_members_enriched AS m ON s.member_id = m.member_id::varchar
)

SELECT * FROM final
