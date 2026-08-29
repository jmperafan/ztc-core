WITH

source AS (
    SELECT * FROM {{ source('ztc', 'invoice_line_items') }}
),

renamed AS (
    SELECT
        line_item_id,
        invoice_id,
        category,
        description,
        CAST(quantity AS NUMBER(6, 0)) AS quantity,
        unit_amount,
        line_amount
    FROM source
)

SELECT * FROM renamed
