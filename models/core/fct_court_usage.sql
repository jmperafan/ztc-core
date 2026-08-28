WITH

int_court_slots AS (
    SELECT * FROM {{ ref('int_court_slots') }}
),

final AS (
    SELECT * FROM int_court_slots
)

SELECT * FROM final
