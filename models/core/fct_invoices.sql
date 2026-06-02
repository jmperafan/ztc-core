WITH invoices AS (
    SELECT * FROM {{ ref('int_invoices') }}
),

final AS (
    SELECT
        invoice_id,
        member_id,
        gender,
        age_group,
        city,
        current_type_of_membership,
        invoice_date,
        due_date,
        paid_date,
        days_to_pay,
        total_amount,
        status,
        is_paid,
        is_overdue,
        payment_method
    FROM invoices
)

SELECT * FROM final
