WITH invoice_line_items AS (
    SELECT * FROM {{ ref('int_invoice_line_items') }}
),

final AS (
    SELECT
        line_item_id,
        invoice_id,
        invoice_date,
        member_id,
        category,
        description,
        quantity,
        unit_amount,
        line_amount
    FROM invoice_line_items
)

SELECT * FROM final
