WITH

stg_invoice_line_items AS (
    SELECT * FROM {{ ref('stg_invoice_line_items') }}
),

int_invoices AS (
    SELECT * FROM {{ ref('int_invoices') }}
),

final AS (
    SELECT
        li.line_item_id,
        li.invoice_id,
        i.invoice_date,
        i.member_id,
        li.category,
        li.description,
        li.quantity,
        li.unit_amount,
        li.line_amount
    FROM stg_invoice_line_items AS li
    LEFT JOIN int_invoices AS i ON li.invoice_id = i.invoice_id
)

SELECT * FROM final
