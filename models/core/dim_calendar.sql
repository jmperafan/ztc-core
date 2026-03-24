with generate_date as (
    select
        dateadd('day', seq4(), date '{{ var('start_date') }}') as date_key
    from table(
        generator(
            rowcount => datediff('day', date '{{ var('start_date') }}', date '{{ var('end_date') }}')
        )
    )
)

select date_key from generate_date
order by date_key desc
