WITH

source AS (
    SELECT * FROM {{ source('ztc', 'equipment_rentals') }}
),

renamed AS (
    SELECT
        rental_id,
        member_id,
        product_id,
        rental_date,
        return_date,
        rental_fee,
        late_fee,
        was_returned
    FROM source
)

SELECT * FROM renamed
