with 

dim_calendar as (
    select * from {{ ref('dim_calendar') }}
),

spine as (
    {%- for court_number in [1, 2, 3, 4, 5] -%}
    select
        {{ court_number }} as court_number,
        date_key as reservation_date
    from dim_calendar
    {%- if not loop.last %} union {% endif -%}
    {% endfor %}
)

select * from spine