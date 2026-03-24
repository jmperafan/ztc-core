with fct_court_usage as (
    select * from {{ ref('fct_court_usage') }}
),

count_of_days as (
    select count(distinct reservation_date) as n
    from fct_court_usage
),

days_per_court as (
    select
        court_number,
        count(distinct reservation_date) as n
    from {{ ref('fct_court_usage') }}
    group by all
)

select * from days_per_court
where n != (
    select n from count_of_days
)

