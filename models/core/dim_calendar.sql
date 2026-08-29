WITH date_spine AS (
    SELECT * FROM {{ ref('int_date_spine') }}
),

final AS (
    SELECT date_key
    FROM date_spine
)

SELECT date_key FROM final
