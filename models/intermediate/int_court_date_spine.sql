WITH

int_date_spine AS (
    SELECT * FROM {{ ref('int_date_spine') }}
),

final AS (
    {%- for court_number in var('court_numbers') -%}
        SELECT
            {{ court_number }} AS court_number,
            date_key AS reservation_date
        FROM int_date_spine
        {%- if not loop.last %} UNION DISTINCT {% endif -%}
    {% endfor %}
)

SELECT * FROM final
