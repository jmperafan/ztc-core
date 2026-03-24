with recursive date_spine as (
    select date '{{ var('start_date') }}' as date_key
    union all
    select dateadd('day', 1, date_key)
    from date_spine
    where date_key < date '{{ var('end_date') }}'
)

select date_key from date_spine
order by date_key desc
