WITH RECURSIVE date_spine AS (
    SELECT DATE '{{ var('start_date') }}' AS date_key
    UNION ALL
    SELECT dateadd('day', 1, date_key)
    FROM date_spine
    WHERE date_key < current_date()
)

SELECT date_key FROM date_spine
ORDER BY date_key DESC
