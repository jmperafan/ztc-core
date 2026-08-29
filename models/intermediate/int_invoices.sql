WITH

stg_invoices AS (
    SELECT * FROM {{ ref('stg_invoices') }}
),

int_club_members_enriched AS (
    SELECT * FROM {{ ref('int_club_members_enriched') }}
),

final AS (
    SELECT
        i.invoice_id,
        i.member_id,
        m.gender,
        m.age_group,
        m.city,
        m.current_type_of_membership,
        i.invoice_date,
        i.due_date,
        i.paid_date,
        DATEDIFF('day', i.invoice_date, i.paid_date) AS days_to_pay,
        i.total_amount,
        i.status,
        i.status = 'Paid' AS is_paid,
        i.status = 'Overdue' AS is_overdue,
        i.payment_method
    FROM stg_invoices AS i
    LEFT JOIN int_club_members_enriched AS m ON i.member_id = m.member_id::varchar
)

SELECT * FROM final
