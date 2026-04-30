{{ config(severity='error') }}

SELECT reservation_id
FROM {{ ref('stg_reservations') }}
WHERE reservation_date > CURRENT_DATE()
