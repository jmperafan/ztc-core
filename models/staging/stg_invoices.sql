WITH

source AS (
    SELECT * FROM {{ source('ztc', 'invoices') }}
),

renamed AS (
    SELECT
        invoice_id,
        member_id,
        invoice_date,
        due_date,
        total_amount,
        status,
        payment_method,
        paid_date
    FROM source
)

SELECT * FROM renamed
