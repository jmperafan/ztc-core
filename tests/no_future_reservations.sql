{{ config(severity='error', group='analytics_engineering') }}

SELECT reservation_id
FROM {{ ref('stg_reservations') }}
WHERE reservation_date > CURRENT_DATE()
