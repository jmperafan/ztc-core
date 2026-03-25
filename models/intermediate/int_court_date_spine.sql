WITH

dim_calendar AS (
    SELECT * FROM {{ ref('dim_calendar') }}
),

spine AS (
    {%- for court_number in var('court_numbers') -%}
        SELECT
            {{ court_number }} AS court_number,
            date_key AS reservation_date
        FROM dim_calendar
        {%- if not loop.last %} UNION DISTINCT {% endif -%}
    {% endfor %}
)

SELECT * FROM spine
